import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Hover: connected devices. Click: device manager. Right click: connect headset.
Module {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var saved: devices.filter(d => d.paired || d.bonded || d.trusted)
    readonly property var discovered: devices.filter(d => !(d.paired || d.bonded || d.trusted))

    // Glyph for a BlueZ icon name such as "audio-headset" or "input-mouse"
    function deviceIcon(device) {
        const icon = device.icon;
        return icon.startsWith("audio") ? "\u{F02CB}"
            : icon.includes("mouse") ? "\u{F037D}"
            : icon.includes("keyboard") ? "\u{F030C}"
            : icon.includes("phone") ? "\u{F011C}"
            : "\u{F00AF}";
    }

    function battery(device) {
        return device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "";
    }

    name: "bluetooth"
    text: !adapter ? "" : !adapter.enabled ? "\u{F00B2}" : connected.length > 0 ? "\u{F00B1}" : "\u{F00AF}"

    onRightClicked: Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/connect-headset.sh"])

    card: ColumnLayout {
        spacing: 6

        Heading {
            text: "Bluetooth"
        }
        Label {
            visible: root.connected.length === 0
            text: root.adapter?.enabled ? "No devices connected" : "Off"
            color: Theme.dim
        }
        Repeater {
            model: root.connected

            RowLayout {
                id: row

                required property BluetoothDevice modelData

                spacing: Theme.padding

                Label {
                    text: root.deviceIcon(row.modelData)
                    color: Theme.good
                }
                Label {
                    Layout.fillWidth: true
                    text: row.modelData.name
                }
                Label {
                    Layout.leftMargin: 16
                    text: root.battery(row.modelData)
                    color: Theme.dim
                }
            }
        }
    }

    menu: ColumnLayout {
        id: manager

        // Saved device whose kebab menu is open
        property var expanded: null

        // Leave no discovery running behind a closed menu
        Component.onDestruction: {
            if (root.adapter?.discovering)
                root.adapter.discovering = false;
        }

        spacing: 2

        RowLayout {
            Layout.preferredWidth: 320
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.bottomMargin: 4

            Heading {
                Layout.fillWidth: true
                text: "Saved devices"
            }
            Toggle {
                checked: root.adapter?.enabled ?? false
                onToggled: root.adapter.enabled = !root.adapter.enabled
            }
        }

        Label {
            Layout.leftMargin: Theme.padding
            visible: root.saved.length === 0
            text: "None"
            color: Theme.dim
        }
        Repeater {
            model: root.saved

            ColumnLayout {
                id: entry

                required property BluetoothDevice modelData
                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                    || modelData.state === BluetoothDeviceState.Disconnecting

                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    spacing: 0

                    MenuItem {
                        icon: root.deviceIcon(entry.modelData)
                        iconColor: entry.modelData.connected ? Theme.good : Theme.text
                        text: entry.modelData.name
                        detail: entry.busy ? BluetoothDeviceState.toString(entry.modelData.state)
                            : entry.modelData.connected ? ("Connected  " + root.battery(entry.modelData)).trim() : ""
                        detailColor: entry.modelData.connected ? Theme.good : Theme.dim
                        onClicked: entry.modelData.connected ? entry.modelData.disconnect() : entry.modelData.connect()
                    }
                    IconButton {
                        icon: "\u{F01D9}"
                        onClicked: manager.expanded = manager.expanded === entry.modelData ? null : entry.modelData
                    }
                }
                MenuItem {
                    Layout.leftMargin: 26
                    visible: manager.expanded === entry.modelData
                    icon: "\u{F01B4}"
                    iconColor: Theme.alert
                    text: "Forget"
                    onClicked: {
                        manager.expanded = null;
                        entry.modelData.forget();
                    }
                }
            }
        }

        MenuItem {
            Layout.topMargin: 10
            visible: root.adapter?.enabled ?? false
            icon: root.adapter?.discovering ? "\u{F0156}" : "\u{F0415}"
            text: root.adapter?.discovering ? "Cancel" : "Add new device"
            detail: root.adapter?.discovering ? "Searching…" : ""
            onClicked: root.adapter.discovering = !root.adapter.discovering
        }
        Repeater {
            model: root.adapter?.discovering ? root.discovered : []

            MenuItem {
                id: found

                required property BluetoothDevice modelData

                Layout.leftMargin: 26
                icon: root.deviceIcon(modelData)
                text: modelData.name || modelData.address
                detail: modelData.pairing ? "Pairing…" : ""
                onClicked: {
                    modelData.trusted = true;
                    modelData.pair();
                }

                Connections {
                    target: found.modelData
                    function onPairedChanged() {
                        if (found.modelData.paired)
                            found.modelData.connect();
                    }
                }
            }
        }
    }
}
