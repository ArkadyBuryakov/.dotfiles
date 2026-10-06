pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager VPN profiles and whether each is up. Polled, as quickshell's
// Networking module does not cover VPNs.
Singleton {
    id: root

    // [{ name, active }]
    property var connections: []
    readonly property var active: connections.filter(c => c.active)

    // Bring a profile up or down; toggle_vpn.sh reports the outcome as a notification
    function toggle(name) {
        Quickshell.execDetached(["sh", "-c", 'exec ~/.config/hypr/scripts/toggle_vpn.sh "$1"', "sh", name]);
        settle.restart();
    }

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "TYPE,ACTIVE,NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.connections = text.split("\n").map(line => line.match(/^(vpn|wireguard):(yes|no):(.*)$/)).filter(m => m)
                    .map(m => ({ name: m[3].replace(/\\(.)/g, "$1"), active: m[2] === "yes" }));
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: list.running = true
    }

    // Pick up the result of a toggle sooner than the next poll
    Timer {
        id: settle
        interval: 1500
        onTriggered: list.running = true
    }
}
