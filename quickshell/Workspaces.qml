import QtQuick
import Quickshell
import Quickshell.Hyprland

// Buttons for the regular workspaces living on this bar's monitor.
//
// Workspaces 1-9 belong to the primary monitor and 11-19 to the secondary (see
// hypr/conf/roles.lua). A monitor holding only the second group is the
// secondary, and shows 11-19 as 1-9. When the secondary is unplugged its
// workspaces move to the primary and keep their real names there.
Row {
    id: root

    required property ShellScreen screen

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property list<HyprlandWorkspace> workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor === monitor)
        .sort((a, b) => a.id - b.id)
    readonly property bool secondary: workspaces.length > 0 && workspaces[0].id > 10

    spacing: 2

    Repeater {
        model: root.workspaces

        Rectangle {
            id: button

            required property HyprlandWorkspace modelData

            // At least 4:3
            width: Math.max(label.implicitWidth + 2 * Theme.padding, Math.ceil(height * 4 / 3))
            height: root.height
            color: modelData.active || mouse.containsMouse ? Theme.accent : "transparent"
            // Outlined while it has windows
            border.width: modelData.toplevels.values.length > 0 ? 2 : 0
            border.color: Theme.grey

            Text {
                id: label
                anchors.centerIn: parent
                // The font metrics centre digits, but they render about half a pixel high
                anchors.verticalCenterOffset: 0.5
                text: root.secondary && button.modelData.id < 20 ? button.modelData.id - 10 : button.modelData.name
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: button.modelData.activate()
            }
        }
    }
}
