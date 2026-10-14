import QtQuick
import Quickshell
import Quickshell.Wayland

// What the strip of an open sidebar (see SidebarPanel.qml) shows while there
// is no window on it: when it is empty, and while a window is dragged around,
// as a place to drop it. Looks like the bar - darkened, blurred wallpaper
// (hypr/conf/sidebar.lua) - and sits under the windows, so that the one
// dragged over it stays in view.
PanelWindow {
    id: backdrop

    required property ShellScreen modelData

    readonly property bool empty: Sidebar.windows(modelData.name).length === 0
    readonly property bool left: Sidebar.side(modelData.name) === "left"

    screen: modelData
    visible: Sidebar.isOpen(modelData.name) && (empty || Sidebar.dragging)
    anchors {
        top: true
        bottom: true
        left: backdrop.left
        right: !backdrop.left
    }
    // The strip itself is what SidebarPanel reserves: lie on it, below the bar
    exclusionMode: ExclusionMode.Ignore
    margins.top: Theme.barHeight
    implicitWidth: Sidebar.stripWidth(modelData)
    color: Theme.bg
    // Takes no input
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-dropzone"

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Sidebar.border
        border.color: Sidebar.dragging ? Theme.accent : Theme.grey
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.padding

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            // nf-md-dock_left / nf-md-dock_right
            text: backdrop.left ? "\u{F10AA}" : "\u{F10AB}"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 64
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Drop a window here"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 5
        }
    }
}
