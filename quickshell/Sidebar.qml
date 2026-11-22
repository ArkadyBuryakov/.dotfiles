pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Regular windows docked as a sidebar: a list of windows, one of which is on
// show - floated, pinned (so it follows every workspace of the monitor) and
// laid over a strip on either side of the screen that SidebarPanel keeps free
// of tiled windows. The others, and all of them while the sidebar is closed,
// wait on a hidden workspace.
//
// Depending on `mode`, each monitor has a sidebar of its own, or there is a
// single one for all of them: opened on one monitor, it leaves the one it was
// on, and takes its windows (and the one on show) along.
//
// Driven by the binds in hypr/conf/key_bindings.lua: hypr/conf/sidebar.lua
// turns them into `sidebar <command>` custom events, and does the window
// handling asked back from here.
Singleton {
    id: root

    // "monitor": a sidebar per monitor. "single": one sidebar, on whichever
    // monitor it was last opened on. Set in config.yaml (Config.qml); the
    // sidebars are carried over when it changes (see convert).
    // Anything but "single" (even nothing, should Config fail to load) is
    // "monitor"
    readonly property string mode: kind(Config.sidebarMode)
    readonly property bool single: mode === "single"
    // Mode the sidebars below are kept in: behind mode until converted
    property string held: ""

    readonly property int defaultWidth: 600
    readonly property int minWidth: 300
    // Width of the drag handle straddling the inner edge of the strip
    readonly property int handle: 8
    // Mirrors general.extend_border_grab_area: how far outside a floating
    // window Hyprland still starts a border resize
    readonly property int grabArea: 15
    // Mirrors general.border_size in hypr/conf/visuals.lua: the window is
    // inset by it, so its border stays on screen
    readonly property int border: 2
    // Height of the tabs, shown once a sidebar holds several windows
    readonly property int tabHeight: 18

    // Output name -> { windows: addresses ("0x..."), active: the address on
    // show, open }. In single mode the one sidebar is under "*", and also
    // has screen: the output it is on (or was, while closed).
    // Kept here and only mirrored into the state file: an adapter property
    // set twice in a row still reads back its first value
    property var sidebars: ({})
    // Output name -> "left" | "right": the side its sidebar is on, or was the
    // last time. Mirrored like the above
    property var sides: ({})
    // The state file has been read back. Not necessarily by the time this
    // is created: after a hot reload the adapter fills in later
    property bool restored: false
    // The state file is read (or found missing): restored once the config
    // is in too, so that its sidebars are taken over in the right mode
    property bool stateRead: false
    // Output name -> strip width, remembered while the sidebar is empty
    readonly property var widths: state.widths

    // A window is being dragged around: an open sidebar shows where to drop it
    property bool dragging: false

    function kind(mode: var): string {
        return mode === "single" ? "single" : "monitor";
    }

    // Key of the sidebar in charge of an output
    function key(name: string): string {
        return single ? "*" : name;
    }

    // Output a sidebar is on, by its key
    function screenOf(key: string): string {
        return single ? (sidebars[key]?.screen ?? "") : key;
    }

    // Sidebar in charge of an output, open there or not
    function record(name: string): var {
        return sidebars[key(name)];
    }

    // Whether the sidebar in charge of an output is the one on it (always,
    // but in single mode)
    function isHere(name: string): bool {
        return !single || record(name)?.screen === name;
    }

    function windows(name: string): var {
        return record(name)?.windows ?? [];
    }

    function active(name: string): string {
        return record(name)?.active ?? "";
    }

    function isOpen(name: string): bool {
        return record(name)?.open === true && isHere(name);
    }

    function side(name: string): string {
        return sides[name] === "left" ? "left" : "right";
    }

    // Height the tabs take off the docked window
    function tabs(name: string): int {
        return windows(name).length > 1 ? tabHeight : 0;
    }

    function maxWidth(screen: ShellScreen): int {
        return Math.floor(screen.width / 2);
    }

    function stripWidth(screen: ShellScreen): int {
        return Math.max(minWidth, Math.min(maxWidth(screen), widths[screen.name] ?? defaultWidth));
    }

    function setWidth(screen: ShellScreen, width: int) {
        state.widths = Object.assign({}, widths, { [screen.name]: width });
    }

    function save() {
        // Would write the empty state over the one still to be read
        if (!restored)
            return;
        state.mode = held;
        state.sidebars = sidebars;
        state.sides = sides;
        file.writeAdapter();
    }

    // Store the sidebar in charge of an output. In single mode that moves it
    // onto the output.
    function set(name: string, sidebar: var) {
        const record = single ? Object.assign({}, sidebar, { screen: name }) : sidebar;
        sidebars = Object.assign({}, sidebars, { [key(name)]: record });
        save();
    }

    // Name of the output whose sidebar holds the window
    function owner(address: string): string {
        const held = Object.keys(sidebars).find(key => sidebars[key].windows.includes(address));
        return held ? screenOf(held) : "";
    }

    // Put a window into the sidebar of a monitor, on show. Given a side, the
    // sidebar goes there.
    function add(address: string, name: string, side: string) {
        if (!Quickshell.screens.some(screen => screen.name === name))
            return;
        if (side === "left" || side === "right")
            sides = Object.assign({}, sides, { [name]: side });
        // Over from another sidebar. The single one just moves along.
        const from = owner(address);
        const moved = from && key(from) !== key(name);
        if (moved)
            detach(address);
        const held = windows(name);
        set(name, {
            windows: held.includes(address) ? held : held.concat([address]),
            active: address,
            open: true
        });
        run((moved ? layout(from, false) : "") + layout(name, true));
    }

    // Stop tracking a window, without touching it: the next one takes over,
    // and a sidebar left empty closes. Returns the output it was on.
    function detach(address: string): string {
        const name = owner(address);
        if (!name)
            return "";
        const sidebar = record(name);
        const rest = sidebar.windows.filter(window => window !== address);
        const next = rest[Math.min(sidebar.windows.indexOf(address), rest.length - 1)] ?? "";
        set(name, {
            windows: rest,
            active: sidebar.active === address ? next : sidebar.active,
            open: sidebar.open && rest.length > 0
        });
        return name;
    }

    // Release a window back into the tiling layout.
    function remove(address: string) {
        const name = detach(address);
        if (name)
            run(`require("conf/sidebar").release("${address}")\n` + layout(name, false));
    }

    // Open the sidebar of a monitor, empty as it may be, or close it. The
    // single sidebar, open on another monitor, comes over instead.
    function toggle(name: string) {
        if (!Quickshell.screens.some(screen => screen.name === name))
            return;
        const open = !isOpen(name);
        set(name, { windows: windows(name), active: active(name), open: open });
        run(layout(name, open));
    }

    // Put the sidebar of a monitor on the other side of it.
    function move(name: string, side: string) {
        if (side === root.side(name) || (side !== "left" && side !== "right"))
            return;
        sides = Object.assign({}, sides, { [name]: side });
        save();
        // Asked from the docked window: the pointer follows it over
        run(layout(name, true));
    }

    // Bring a window of a sidebar on show. Unless warping, the focus goes to
    // it but the cursor stays put (a click on its tab).
    function select(address: string, warp: bool) {
        const name = owner(address);
        if (!name)
            return;
        set(name, Object.assign({}, record(name), { active: address, open: true }));
        run(layout(name, true, warp));
    }

    // Step through the windows of a sidebar.
    function cycle(name: string, step: int) {
        const held = windows(name);
        if (held.length > 1)
            select(held[(held.indexOf(active(name)) + step + held.length) % held.length], true);
    }

    // Move the tab on show along the tabs of a sidebar, stopping at either end.
    function shift(name: string, step: int) {
        const held = windows(name);
        const from = held.indexOf(active(name));
        const to = Math.max(0, Math.min(held.length - 1, from + step));
        if (from < 0 || to === from)
            return;
        const order = held.filter(address => address !== held[from]);
        order.splice(to, 0, held[from]);
        set(name, Object.assign({}, record(name), { windows: order }));
    }

    // Release every window of a sidebar.
    function dissolve(name: string) {
        // The single sidebar is elsewhere
        if (!isHere(name))
            return;
        const held = windows(name);
        const rest = Object.assign({}, sidebars);
        delete rest[key(name)];
        sidebars = rest;
        save();
        // Not right away: on its way out a monitor leaves its workspaces
        // in no state to tile a window on
        if (held.length > 0)
            run(`hl.timer(function()\n${held.map(address => `require("conf/sidebar").release("${address}")\n`).join("")}end, { timeout = 500, type = "oneshot" })`);
    }

    // Fit the windows of a sidebar to its state.
    function apply(name: string) {
        run(layout(name, false));
    }

    // Lua putting the windows of a sidebar where they belong: the active one
    // into the strip (taking the focus, if asked, and the cursor with it
    // unless warp is false), the rest out of sight.
    function layout(name: string, focus: bool, warp: var): string {
        // The single sidebar is elsewhere: its windows are none of this
        // output's business
        if (!isHere(name))
            return "";
        const screen = Quickshell.screens.find(screen => screen.name === name);
        const shown = screen && isOpen(name) ? active(name) : "";
        // Geometry comes from the compositor: it is current even right
        // after the monitor changed its mode or scale.
        let script = shown ? `require("conf/sidebar").show("${shown}", "${name}", "${side(name)}", ${stripWidth(screen)}, ${tabs(name)}, ${border}, ${focus}, ${warp !== false})\n` : "";
        for (const address of windows(name)) {
            if (address !== shown)
                script += `require("conf/sidebar").stash("${address}")\n`;
        }
        return script;
    }

    function run(script: string) {
        if (script)
            Quickshell.execDetached(["hyprctl", "eval", script]);
    }

    // Take the sidebars over from the state file, once it is read (or
    // found missing), and check them against the windows there are.
    function restore() {
        if (restored || !stateRead || !Config.loaded)
            return;
        // Written before there was a mode: one sidebar per monitor
        const from = kind(state.mode);
        sidebars = convert(state.sidebars ?? {}, from);
        held = single ? "single" : "monitor";
        sides = state.sides ?? {};
        restored = true;
        if (from !== held)
            save();
        check.running = true;
    }

    // Sidebars stored in another mode, as this one keeps them. Never drops a
    // window: what is stored in neither shape is kept as it is. The windows
    // themselves are put in place by check, once the dead ones are dropped.
    function convert(stored: var, from: string): var {
        const one = stored["*"];
        if (kind(from) === (single ? "single" : "monitor") || (!single && !one))
            return stored;
        const focused = Hyprland.focusedMonitor?.name ?? "";
        if (!single) {
            // The single sidebar becomes the one of the monitor it is on
            const screen = one.screen || focused || (Quickshell.screens[0]?.name ?? "");
            return screen ? { [screen]: { windows: one.windows ?? [], active: one.active ?? "", open: one.open === true } } : stored;
        }
        // All windows go into one sidebar. It goes where one is open,
        // preferably on the focused monitor, or else where one has windows.
        const names = Object.keys(stored).filter(name => stored[name].windows?.length > 0 || stored[name].open);
        const open = names.filter(name => stored[name].open);
        const pick = list => list.includes(focused) ? focused : list[0];
        const screen = pick(open) ?? pick(names);
        if (!screen)
            return {};
        // Its own tabs first: the one on show stays so
        const windows = [screen].concat(names.filter(name => name !== screen)).reduce((all, name) => all.concat(stored[name].windows ?? []), []);
        return {
            "*": {
                windows: windows,
                active: stored[screen].active || (windows[0] ?? ""),
                open: open.length > 0,
                screen: screen
            }
        };
    }

    // Switched while running: carry the sidebars over and put their windows
    // where the new mode has them. Not from inside the change: single may not
    // have followed mode yet.
    onModeChanged: Qt.callLater(switchMode)

    function switchMode() {
        if (!restored || held === mode)
            return;
        sidebars = convert(sidebars, held);
        held = mode;
        save();
        for (const screen of Quickshell.screens)
            apply(screen.name);
    }

    Component.onCompleted: {
        if (file.loaded) {
            stateRead = true;
            restore();
        }
    }

    Connections {
        target: Config
        function onLoadedChanged() {
            root.restore();
        }
    }

    FileView {
        id: file
        path: Quickshell.statePath("sidebar.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.stateRead = true;
            root.restore();
        }
        onLoadFailed: {
            root.stateRead = true;
            root.restore();
        }

        JsonAdapter {
            id: state
            // Mode the sidebars below are stored in
            property string mode: ""
            property var sidebars: ({})
            property var sides: ({})
            property var widths: ({})
        }
    }

    // Addresses do not survive a Hyprland restart, and a monitor may be gone:
    // drop what is left of those, and put the rest back in place. A window
    // left in the stash or docked by no sidebar at all (a state file lost or
    // out of step) would stay out of reach: it goes back to the tiling layout.
    Process {
        id: check
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const clients = JSON.parse(text);
                const alive = clients.map(client => client.address);
                const tracked = Object.keys(root.sidebars).reduce((all, key) => all.concat(root.sidebars[key].windows ?? []), []);
                const stranded = clients.filter(client => !tracked.includes(client.address) && (client.workspace?.name === "special:sidebar" || (client.tags ?? []).some(tag => tag.replace(/\*$/, "") === "sidebar")));
                root.run(stranded.map(client => `require("conf/sidebar").release("${client.address}")\n`).join(""));
                for (const key of Object.keys(root.sidebars)) {
                    const name = root.screenOf(key);
                    root.windows(name).filter(address => !alive.includes(address)).forEach(address => root.detach(address));
                    if (Quickshell.screens.some(screen => screen.name === name))
                        root.apply(name);
                    else
                        root.dissolve(name);
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "closewindow": {
                const address = `0x${event.data}`;
                const shown = root.active(root.owner(address)) === address;
                const name = root.detach(address);
                // The next tab takes over the focus of the one that was on show
                if (name)
                    root.run(root.layout(name, shown));
                break;
            }
            // Tiled by hand: it is no longer in the sidebar
            case "changefloatingmode": {
                const [address, on] = event.data.split(",");
                if (on === "0")
                    root.remove(`0x${address}`);
                break;
            }
            case "monitorremoved":
                root.dissolve(event.data);
                break;
            // From hypr/conf/sidebar.lua
            case "custom": {
                const [target, command, ...args] = event.data.split(" ");
                if (target !== "sidebar")
                    break;
                switch (command) {
                case "toggle":
                    root.toggle(args[0]);
                    break;
                case "add":
                    root.add(args[0], args[1], args[2] ?? "");
                    break;
                case "side":
                    root.move(args[0], args[1]);
                    break;
                case "remove":
                    root.remove(args[0]);
                    break;
                case "select":
                    root.select(args[0], true);
                    break;
                case "drag":
                    root.dragging = args[0] === "1";
                    break;
                case "cycle":
                    root.cycle(args[0], parseInt(args[1]));
                    break;
                case "shift":
                    root.shift(args[0], parseInt(args[1]));
                    break;
                }
                break;
            }
            }
        }
    }
}
