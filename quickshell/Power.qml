import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

// System menu: tray apps (StatusNotifierItems such as MEGAsync, Telegram) on
// top, session actions below. Tray row: click activates the app, right click
// opens its own menu.
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

    // Referenced here, not only inside the menu, so qs registers the tray
    // watcher at startup and apps can find a tray before the menu is opened.
    readonly property var trayItems: SystemTray.items.values

    function trayTitle(item) {
        // Some apps put status lines in the tooltip ("MEGA 6.7.0\nUp to date")
        return (item.tooltipTitle || item.title || item.id).split("\n")[0];
    }

    // The app's own menu, anchored below this button on the bar. Shown from the
    // bar window, since this popup closes first.
    function showTrayMenu(item) {
        Popups.close();
        const pos = root.mapToItem(null, 0, root.height);
        item.display(root.QsWindow.window, pos.x, pos.y);
    }

    name: "power"
    text: "\u{F0906}"

    menu: ColumnLayout {
        spacing: 2

        Heading {
            visible: root.trayItems.length > 0
            Layout.leftMargin: Theme.padding
            text: "Apps"
        }

        Repeater {
            model: root.trayItems

            Rectangle {
                id: trayRow

                required property SystemTrayItem modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 180
                implicitHeight: Theme.rowHeight
                color: trayMouse.containsMouse ? Theme.accent : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padding
                    anchors.rightMargin: Theme.padding
                    spacing: Theme.padding

                    Item {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            sourceSize.width: 32
                            sourceSize.height: 32
                            source: trayRow.modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: root.trayTitle(trayRow.modelData)
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: event => {
                        const item = trayRow.modelData;
                        if (event.button === Qt.RightButton || (item.onlyMenu && item.hasMenu)) {
                            root.showTrayMenu(item);
                            return;
                        }
                        Popups.close();
                        if (event.button === Qt.MiddleButton)
                            item.secondaryActivate();
                        else
                            item.activate();
                    }
                }
            }
        }

        // Divider in the frame's border style, running across the popup's
        // padding so it meets the border on both sides.
        Item {
            visible: root.trayItems.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: Theme.borderWidth

            Rectangle {
                x: -Theme.popupPadding
                width: parent.width + 2 * Theme.popupPadding
                height: parent.height
                color: Theme.accent
            }
        }

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
