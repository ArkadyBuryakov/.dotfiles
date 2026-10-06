import QtQuick
import QtQuick.Layouts

// Clickable popup row: icon, text, and a dimmed detail on the right.
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Theme.text
    property string text: ""
    property string detail: ""
    property color detailColor: Theme.dim

    signal clicked

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth + 2 * Theme.padding
    implicitHeight: Theme.rowHeight
    color: mouse.containsMouse ? Theme.accent : "transparent"

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Theme.padding
        anchors.rightMargin: Theme.padding
        spacing: Theme.padding

        Label {
            // Glyphs differ in width; a fixed slot keeps the texts aligned
            Layout.preferredWidth: 18
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            color: mouse.containsMouse ? Theme.text : root.iconColor
            visible: text !== ""
        }
        Label {
            Layout.fillWidth: true
            text: root.text
            elide: Text.ElideRight
        }
        Label {
            text: root.detail
            color: mouse.containsMouse ? Theme.text : root.detailColor
            visible: text !== ""
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
