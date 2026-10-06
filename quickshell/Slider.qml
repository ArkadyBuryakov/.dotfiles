import QtQuick

// Horizontal slider for a 0..1 value. Emits moved() while dragged or scrolled;
// the owner is expected to feed the new value back.
Item {
    id: root

    property real value: 0
    property color fill: Theme.accent

    signal moved(real value)

    implicitWidth: 220
    implicitHeight: 20

    Meter {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        value: root.value
        fill: root.fill
    }

    Rectangle {
        x: Math.round((parent.width - width) * Math.max(0, Math.min(1, root.value)))
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: 16
        color: Theme.text
    }

    MouseArea {
        anchors.fill: parent
        function seek(x) {
            root.moved(Math.max(0, Math.min(1, x / width)));
        }
        onPressed: event => seek(event.x)
        onPositionChanged: event => seek(event.x)
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
