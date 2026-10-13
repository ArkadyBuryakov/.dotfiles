pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Regular windows docked as a sidebar. Each monitor has its own: a list of
// windows, one of which is on show - floated, pinned (so it follows every
// workspace of the monitor) and laid over a strip of the screen that
// SidebarPanel keeps free of tiled windows. The others, and all of them while
// the sidebar is closed, wait on a hidden workspace.
//
// Driven by the binds in hypr/conf/key_bindings.lua: hypr/conf/sidebar.lua
// turns them into `sidebar <command>` custom events, and does the window
// handling asked back from here.
Singleton {
    id: root

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
    readonly property int tabHeight: Theme.barHeight

    // Output name -> { windows: addresses ("0x..."), active: the address on
    // show, open }
    // Kept here and only mirrored into the state file: an adapter property
    // set twice in a row still reads back its first value
    property var sidebars: ({})
    // Output name -> strip width, remembered while the sidebar is empty
    readonly property var widths: state.widths

    function windows(name: string): var {
        return sidebars[name]?.windows ?? [];
    }

    function active(name: string): string {
        return sidebars[name]?.active ?? "";
    }

    function isOpen(name: string): bool {
        return sidebars[name]?.open === true && windows(name).length > 0;
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
        state.sidebars = sidebars;
        file.writeAdapter();
    }

    function set(name: string, sidebar: var) {
        sidebars = Object.assign({}, sidebars, { [name]: sidebar });
        save();
    }

    // Name of the output whose sidebar holds the window
    function owner(address: string): string {
        return Object.keys(sidebars).find(name => sidebars[name].windows.includes(address)) ?? "";
    }

    // Put a window into the sidebar of a monitor, on show.
    function add(address: string, name: string) {
        if (!Quickshell.screens.some(screen => screen.name === name))
            return;
        const from = owner(address);
        if (from && from !== name)
            detach(address);
        const held = windows(name);
        set(name, {
            windows: held.includes(address) ? held : held.concat([address]),
            active: address,
            open: true
        });
        run((from && from !== name ? layout(from, false) : "") + layout(name, true));
    }

    // Stop tracking a window, without touching it: the next one takes over,
    // and a sidebar left empty closes. Returns the output it was on.
    function detach(address: string): string {
        const name = owner(address);
        if (!name)
            return "";
        const sidebar = sidebars[name];
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

    // Open the sidebar of a monitor, or close it.
    function toggle(name: string) {
        if (windows(name).length === 0)
            return;
        const open = !sidebars[name].open;
        set(name, Object.assign({}, sidebars[name], { open: open }));
        run(layout(name, open));
    }

    // Bring a window of a sidebar on show.
    function select(address: string) {
        const name = owner(address);
        if (!name)
            return;
        set(name, Object.assign({}, sidebars[name], { active: address, open: true }));
        run(layout(name, true));
    }

    // Step through the windows of a sidebar.
    function cycle(name: string, step: int) {
        const held = windows(name);
        if (held.length > 1)
            select(held[(held.indexOf(active(name)) + step + held.length) % held.length]);
    }

    // Release every window of a sidebar.
    function dissolve(name: string) {
        const held = windows(name);
        const rest = Object.assign({}, sidebars);
        delete rest[name];
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
    // into the strip (taking the focus, if asked), the rest out of sight.
    function layout(name: string, focus: bool): string {
        const screen = Quickshell.screens.find(screen => screen.name === name);
        const shown = screen && isOpen(name) ? active(name) : "";
        // Geometry comes from the compositor: it is current even right
        // after the monitor changed its mode or scale.
        let script = shown ? `require("conf/sidebar").show("${shown}", "${name}", ${stripWidth(screen)}, ${tabs(name)}, ${border}, ${focus})\n` : "";
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

    Component.onCompleted: sidebars = state.sidebars

    FileView {
        id: file
        path: Quickshell.statePath("sidebar.json")
        blockLoading: true
        printErrors: false

        JsonAdapter {
            id: state
            property var sidebars: ({})
            property var widths: ({})
        }
    }

    // Addresses do not survive a Hyprland restart, and a monitor may be gone:
    // drop what is left of those, and put the rest back in place.
    Process {
        command: ["hyprctl", "clients", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const alive = JSON.parse(text).map(client => client.address);
                for (const name of Object.keys(root.sidebars)) {
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
                    root.add(args[0], args[1]);
                    break;
                case "remove":
                    root.remove(args[0]);
                    break;
                case "select":
                    root.select(args[0]);
                    break;
                case "cycle":
                    root.cycle(args[0], parseInt(args[1]));
                    break;
                }
                break;
            }
            }
        }
    }
}
