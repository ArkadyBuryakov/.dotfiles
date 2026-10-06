import QtQuick
import QtQuick.Layouts
import Quickshell

// Session menu
Module {
    id: root

    readonly property var actions: [
        { icon: "\u{F033E}", text: "Lock", command: "hyprlock" },
        { icon: "\u{F04B2}", text: "Suspend", command: "systemctl suspend" },
        { icon: "\u{F0904}", text: "Hibernate", command: "systemctl hybrid-sleep" },
        { icon: "\u{F0343}", text: "Logout", command: "loginctl terminate-user $USER" },
        { icon: "\u{F0709}", text: "Reboot", command: "systemctl reboot" },
        { icon: "\u{F0425}", text: "Shutdown", command: "systemctl poweroff" },
    ]

    name: "power"
    text: "\u{F0906}"

    menu: ColumnLayout {
        spacing: 2

        Repeater {
            model: root.actions

            MenuItem {
                required property var modelData

                Layout.preferredWidth: 180
                icon: modelData.icon
                text: modelData.text
                onClicked: {
                    Popups.close();
                    Quickshell.execDetached(["sh", "-c", modelData.command]);
                }
            }
        }
    }
}
