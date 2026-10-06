pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tracks the one open module menu, and lets menus be driven from outside:
//   qs ipc call bar toggle <module name>   open/close a menu
//   qs ipc call bar peek <module name>     show/hide a hover card
//   qs ipc call bar close
// Requests go to the bar on the focused monitor.
Singleton {
    id: root

    // The Module whose menu is open
    property var active: null

    signal request(string name, bool menu)

    function toggle(module) {
        active = active === module ? null : module;
    }

    function close() {
        active = null;
    }

    IpcHandler {
        target: "bar"

        function toggle(name: string): void {
            root.request(name, true);
        }
        function peek(name: string): void {
            root.request(name, false);
        }
        function close(): void {
            root.close();
        }
    }
}
