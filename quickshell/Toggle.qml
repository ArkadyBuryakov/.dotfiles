import QtQuick

// On/off switch
Rectangle {
    id: root

    property bool checked: false

    signal toggled

    implicitWidth: 34
    implicitHeight: 16
    color: checked ? Theme.accent : Theme.surface
    border.width: 1
    border.color: Theme.accent

    Rectangle {
        x: root.checked ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        color: Theme.text
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled()
    }
}
