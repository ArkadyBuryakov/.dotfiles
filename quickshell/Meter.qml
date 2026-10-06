import QtQuick

// Horizontal gauge for a 0..1 value
Rectangle {
    id: root

    property real value: 0
    property color fill: Theme.accent

    implicitWidth: 100
    implicitHeight: 6
    color: Theme.surface

    Rectangle {
        width: Math.round(parent.width * Math.max(0, Math.min(1, root.value)))
        height: parent.height
        color: root.fill
    }
}
