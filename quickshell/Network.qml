import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Hover: connection details. Click: Wi-Fi and VPN selector. Right click: nmtui.
Module {
    id: root

    readonly property list<string> wifiIcons: ["\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F05A9}"]
    readonly property string wiredIcon: "\u{F0002}"
    readonly property string vpnIcon: "\u{F0582}"

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: wifiDevice?.connected ? wifiDevice : null
    readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property string iface: (wired ?? wifi)?.name ?? ""

    // Bytes per second, averaged over the sampling interval
    property real down: 0
    property real up: 0
    property var lastSample: null

    function wifiIcon(strength) {
        return wifiIcons[Math.min(wifiIcons.length - 1, Math.floor(strength * wifiIcons.length))];
    }

    function rate(bytes) {
        const units = ["B/s", "kB/s", "MB/s", "GB/s"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) {
            bytes /= 1000;
            i++;
        }
        return (i === 0 ? Math.round(bytes) : bytes.toFixed(1)) + " " + units[i];
    }

    name: "network"
    text: wired ? wiredIcon : wifi ? wifiIcon(wifiNetwork?.signalStrength ?? 0) : "\u{F05AA}"

    onRightClicked: Quickshell.execDetached(["sh", "-c", "kitty ~/.config/hypr/scripts/nm-tui-delay.sh"])
    onIfaceChanged: lastSample = null

    card: ColumnLayout {
        spacing: 6

        RowLayout {
            spacing: Theme.padding

            Label {
                text: root.text
            }
            Label {
                Layout.fillWidth: true
                text: root.wired ? "Wired" : root.wifiNetwork?.name ?? "Disconnected"
            }
            Label {
                visible: !root.wired && root.wifiNetwork !== null
                text: Math.round((root.wifiNetwork?.signalStrength ?? 0) * 100) + "%"
                color: Theme.dim
            }
        }
        RowLayout {
            visible: root.iface !== ""
            spacing: 16

            Label {
                Layout.fillWidth: true
                text: root.iface
                color: Theme.dim
            }
            Label {
                text: "⇣ " + root.rate(root.down)
            }
            Label {
                text: "⇡ " + root.rate(root.up)
            }
        }
        Heading {
            Layout.topMargin: 4
            visible: Vpn.active.length > 0
            text: "VPN"
        }
        Repeater {
            model: Vpn.active

            RowLayout {
                id: vpn

                required property var modelData

                spacing: Theme.padding

                Label {
                    text: root.vpnIcon
                    color: Theme.good
                }
                Label {
                    text: vpn.modelData.name
                }
            }
        }
    }

    menu: ColumnLayout {
        id: selector

        // Network whose passphrase is being asked for
        property var pending: null

        readonly property var networks: [...(root.wifiDevice?.networks.values ?? [])]
            .sort((a, b) => b.connected - a.connected || b.signalStrength - a.signalStrength)

        // Scan only while the selector is open
        Component.onCompleted: {
            if (root.wifiDevice)
                root.wifiDevice.scannerEnabled = true;
        }
        Component.onDestruction: {
            if (root.wifiDevice)
                root.wifiDevice.scannerEnabled = false;
        }

        spacing: 2

        RowLayout {
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.bottomMargin: 4

            Heading {
                Layout.fillWidth: true
                text: "Wi-Fi"
            }
            Toggle {
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        ListView {
            id: list
            Layout.preferredWidth: 320
            Layout.preferredHeight: Math.min(contentHeight, 8 * Theme.rowHeight)
            visible: count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: selector.networks

            delegate: ColumnLayout {
                id: entry

                required property var modelData
                readonly property bool open: modelData.security === WifiSecurityType.Open
                readonly property bool asking: selector.pending === modelData

                width: list.width
                spacing: 0

                MenuItem {
                    icon: root.wifiIcon(entry.modelData.signalStrength)
                    iconColor: entry.modelData.connected ? Theme.good : Theme.text
                    text: entry.modelData.name
                    detail: entry.modelData.stateChanging ? ConnectionState.toString(entry.modelData.state)
                        : entry.modelData.connected ? "Connected"
                        : entry.open ? "" : entry.modelData.known ? "Saved  \u{F033E}" : "\u{F033E}"
                    detailColor: entry.modelData.connected ? Theme.good : Theme.dim
                    onClicked: {
                        if (entry.modelData.connected)
                            entry.modelData.disconnect();
                        else if (entry.modelData.known || entry.open)
                            entry.modelData.connect();
                        else
                            selector.pending = entry.asking ? null : entry.modelData;
                    }
                }

                // Passphrase prompt for a secured network seen for the first time
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    Layout.bottomMargin: 4
                    implicitHeight: Theme.rowHeight
                    visible: entry.asking
                    color: Theme.surface

                    TextInput {
                        id: passphrase
                        anchors.fill: parent
                        anchors.leftMargin: Theme.padding
                        anchors.rightMargin: Theme.padding
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        echoMode: TextInput.Password
                        focus: entry.asking
                        onVisibleChanged: {
                            if (visible)
                                forceActiveFocus();
                        }
                        onAccepted: {
                            entry.modelData.connectWithPsk(text);
                            selector.pending = null;
                        }
                        Keys.onEscapePressed: selector.pending = null

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: passphrase.text === ""
                            text: "Passphrase, then Enter"
                            color: Theme.dim
                        }
                    }
                }
            }
        }

        Label {
            Layout.preferredWidth: 320
            Layout.leftMargin: Theme.padding
            visible: list.count === 0
            text: Networking.wifiEnabled ? "Scanning…" : "Wi-Fi is off"
            color: Theme.dim
        }

        Heading {
            Layout.leftMargin: Theme.padding
            Layout.topMargin: 10
            Layout.bottomMargin: 4
            visible: Vpn.connections.length > 0
            text: "VPN"
        }
        Repeater {
            model: Vpn.connections

            MenuItem {
                required property var modelData

                icon: root.vpnIcon
                iconColor: modelData.active ? Theme.good : Theme.text
                text: modelData.name
                detail: modelData.active ? "Connected" : ""
                detailColor: Theme.good
                onClicked: Vpn.toggle(modelData.name)
            }
        }
    }

    Process {
        id: counters
        command: ["cat", `/sys/class/net/${root.iface}/statistics/rx_bytes`, `/sys/class/net/${root.iface}/statistics/tx_bytes`]
        stdout: StdioCollector {
            onStreamFinished: {
                const [rx, tx] = text.trim().split("\n").map(Number);
                const sample = { rx, tx, time: Date.now() };
                const last = root.lastSample;
                if (last && sample.time > last.time) {
                    const seconds = (sample.time - last.time) / 1000;
                    root.down = Math.max(0, rx - last.rx) / seconds;
                    root.up = Math.max(0, tx - last.tx) / seconds;
                }
                root.lastSample = sample;
            }
        }
    }

    Timer {
        interval: 5000
        running: root.iface !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: counters.running = true
    }
}
