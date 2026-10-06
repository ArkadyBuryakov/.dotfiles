import QtQuick
import Quickshell
import Quickshell.Io

// Runs `command` every `interval` ms and exposes its output, which is expected
// to be a single JSON object: {"text": ..., "tooltip": ..., "class": ...}.
// No output clears all three.
Scope {
    id: root

    required property list<string> command
    property int interval: 1000

    property string text: ""
    property string tooltip: ""
    property string cls: ""

    function refresh() {
        proc.running = true;
    }

    Process {
        id: proc
        command: root.command
        stdout: StdioCollector {
            onStreamFinished: {
                let out = {};
                try {
                    out = JSON.parse(text);
                } catch (e) {}
                root.text = out.text ?? "";
                root.tooltip = out.tooltip ?? "";
                root.cls = out.class ?? "";
            }
        }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
