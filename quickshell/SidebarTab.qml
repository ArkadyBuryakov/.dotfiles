import QtQuick
import Quickshell.Hyprland

// A window of a sidebar holding several: click to bring it on show.
Rectangle {
    id: tab

    // Address ("0x...") of the window
    required property string modelData
    required property bool active

    readonly property HyprlandToplevel toplevel: Hyprland.toplevels.values.find(t => `0x${t.address}` === modelData) ?? null

    color: active ? Theme.accent : mouse.containsMouse ? Theme.surface : Theme.popupBg

    Text {
        anchors.fill: parent
        anchors.leftMargin: Theme.padding
        anchors.rightMargin: Theme.padding
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: tab.toplevel?.title ?? ""
        color: tab.active ? Theme.fg : Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Sidebar.select(tab.modelData)
    }
}
