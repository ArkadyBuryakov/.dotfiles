import QtQuick

// Square glyph button for popup rows and headers
Rectangle {
    id: root

    property alias icon: label.text
    property alias iconColor: label.color

    signal clicked

    implicitWidth: Theme.rowHeight
    implicitHeight: Theme.rowHeight
    color: mouse.containsMouse ? Theme.accent : "transparent"

    Label {
        id: label
        anchors.centerIn: parent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
