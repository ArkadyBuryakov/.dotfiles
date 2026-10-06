pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Layouts of the built-in keyboard as short codes ("en", "ru", ...), and
// which of them is active.
Singleton {
    id: root

    readonly property string device: "at-translated-set-2-keyboard"
    property list<string> layouts: []
    property int index: 0
    readonly property string layout: layouts[index] ?? ""

    // Switch to the next configured layout, wrapping around
    function next() {
        if (layouts.length > 0)
            Quickshell.execDetached(["sh", "-c", `~/.config/hypr/scripts/switch-kb-layout.sh ${(index + 1) % layouts.length}`]);
    }

    Process {
        id: proc
        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const kb = JSON.parse(text).keyboards.find(k => k.name === root.device);
                if (!kb)
                    return;
                root.layouts = kb.layout.split(",").map(code => code === "us" ? "en" : code);
                root.index = kb.active_layout_index;
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout" && event.data.startsWith(root.device + ","))
                proc.running = true;
        }
    }
}
