pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// A regular window docked as a sidebar: floated, pinned (so it follows every
// workspace of its monitor) and laid over a strip of the screen that
// SidebarPanel keeps free of tiled windows. One window per monitor.
//
// Toggled for the focused window with `qs ipc call sidebar toggle`.
Singleton {
    id: root

    readonly property int defaultWidth: 600
    readonly property int minWidth: 300
    // Width of the drag handle straddling the inner edge of the strip
    readonly property int handle: 8
    // Mirrors general.border_size in hypr/conf/visuals.lua: the window is
    // inset by it, so its border stays on screen
    readonly property int border: 2

    // Output name -> address ("0x...") of the window docked there
    readonly property var docked: state.docked
    // Output name -> strip width, remembered across undocking
    readonly property var widths: state.widths

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
        file.writeAdapter();
    }

    // Dock the focused window on its monitor, or release it if it is docked.
    function toggle() {
        const active = Hyprland.activeToplevel;
        if (!active)
            return;
        const address = `0x${active.address}`;
        const current = Object.keys(docked).find(name => docked[name] === address);
        if (current) {
            undock(current);
            return;
        }
        const name = (active.monitor ?? Hyprland.focusedMonitor)?.name;
        const screen = Quickshell.screens.find(s => s.name === name);
        if (!screen)
            return;
        if (docked[name])
            undock(name);
        state.docked = Object.assign({}, docked, { [name]: address });
        save();
        apply(screen);
    }

    // Stop tracking the window docked on a monitor, without touching it.
    function forget(name: string) {
        const rest = Object.assign({}, docked);
        delete rest[name];
        state.docked = rest;
        save();
    }

    // Release the window docked on a monitor back into the tiling layout.
    function undock(name: string) {
        const address = docked[name];
        if (!address)
            return;
        forget(name);
        Quickshell.execDetached(["hyprctl", "eval", `
            local w = hl.get_window("address:${address}")
            if not w then return end
            if w.pinned then hl.dispatch(hl.dsp.window.pin({ window = w })) end
            if w.floating then hl.dispatch(hl.dsp.window.float({ action = "disable", window = w })) end
        `]);
    }

    // Fit the docked window into the strip of its monitor.
    function apply(screen: ShellScreen) {
        const address = docked[screen.name];
        if (!address)
            return;
        const strip = stripWidth(screen);
        // Geometry comes from the compositor: it is current even right
        // after the monitor changed its mode or scale.
        Quickshell.execDetached(["hyprctl", "eval", `
            local w = hl.get_window("address:${address}")
            local m = hl.get_monitor("${screen.name}")
            if not w or not m then return end
            if w.fullscreen ~= 0 then
                local mode = w.fullscreen == 1 and "maximized" or "fullscreen"
                hl.dispatch(hl.dsp.window.fullscreen({ action = "unset", mode = mode, window = w }))
            end
            if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "enable", window = w })) end
            if not w.pinned then hl.dispatch(hl.dsp.window.pin({ window = w })) end
            local right = m.x + m.width / m.scale
            local height = m.height / m.scale - m.reserved.top - m.reserved.bottom
            hl.dispatch(hl.dsp.window.resize({
                x = ${strip - 2 * border},
                y = math.floor(height - ${2 * border}),
                window = w,
            }))
            hl.dispatch(hl.dsp.window.move({
                x = math.floor(right - ${strip - border}),
                y = math.floor(m.y + m.reserved.top + ${border}),
                window = w,
            }))
        `]);
    }

    FileView {
        id: file
        path: Quickshell.statePath("sidebar.json")
        blockLoading: true
        printErrors: false

        JsonAdapter {
            id: state
            property var docked: ({})
            property var widths: ({})
        }
    }

    // Addresses do not survive a Hyprland restart: drop the ones that are gone.
    Process {
        command: ["hyprctl", "clients", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const alive = JSON.parse(text).map(client => client.address);
                for (const name of Object.keys(root.docked)) {
                    if (!alive.includes(root.docked[name]))
                        root.forget(name);
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = dockedOn => Object.keys(root.docked).find(n => root.docked[n] === dockedOn);
            switch (event.name) {
            case "closewindow": {
                const monitor = name(`0x${event.data}`);
                if (monitor)
                    root.forget(monitor);
                break;
            }
            // Tiled or unpinned by hand: it is no longer a sidebar
            case "changefloatingmode":
            case "pin": {
                const [address, on] = event.data.split(",");
                const monitor = name(`0x${address}`);
                if (monitor && on === "0")
                    root.undock(monitor);
                break;
            }
            case "monitorremoved":
                root.undock(event.data);
                break;
            }
        }
    }

    IpcHandler {
        target: "sidebar"

        function toggle(): void {
            root.toggle();
        }
    }
}
