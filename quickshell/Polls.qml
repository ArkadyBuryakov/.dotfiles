pragma Singleton

import QtQuick
import Quickshell

// Script-backed module data. Lives in a singleton so each command runs once,
// not once per monitor.
Singleton {
    readonly property JsonPoll dnd: JsonPoll {
        command: ["sh", "-c", "makoctl mode | grep -q do-not-disturb && echo '"
            + JSON.stringify({ text: "\u{F009B}", class: "active", tooltip: "Do not disturb: ON" }) + "'"]
        interval: 1000
    }

    // Disabled along with their modules in Bar.qml
    // readonly property JsonPoll anki: JsonPoll {
    //     command: [Quickshell.shellPath("scripts/anki-status.sh")]
    //     interval: 300000
    // }

    // readonly property JsonPoll clamav: JsonPoll {
    //     command: [Quickshell.shellPath("scripts/clamav-status.sh")]
    //     interval: 1000
    // }
}
