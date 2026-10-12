import QtQuick
import Quickshell
import Quickshell.Wayland

// The strip a docked window (see Sidebar.qml) sits on. It is invisible and
// only does two things: its exclusive zone keeps tiled windows out of the
// strip, and a handle over its inner edge drags the width.
PanelWindow {
    id: panel

    required property ShellScreen modelData

    readonly property int stripWidth: Sidebar.stripWidth(modelData)

    screen: modelData
    visible: Sidebar.docked[modelData.name] !== undefined
    anchors {
        top: true
        bottom: true
        right: true
    }
    // The surface always spans the widest possible strip (plus the half of the
    // handle that sticks out of it), so that it does not resize under the
    // pointer while the handle is dragged.
    implicitWidth: Sidebar.maxWidth(modelData) + Sidebar.handle / 2
    exclusiveZone: stripWidth
    color: "transparent"
    mask: Region {
        item: handle
    }

    // Same layer as the bar: exclusive zones are handed out layer by layer,
    // and from a lower one the strip would cut the bar short.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-sidebar"

    onStripWidthChanged: resize.start()
    onVisibleChanged: resize.start()
    // The monitor changed its mode or scale
    onWidthChanged: resize.start()
    onHeightChanged: resize.start()

    // Follow the handle at ~30 updates a second
    Timer {
        id: resize
        interval: 33
        onTriggered: Sidebar.apply(panel.screen)
    }

    Rectangle {
        id: handle

        // Centred on the strip edge, over the borders of the windows on both sides
        x: panel.width - panel.stripWidth - width / 2
        width: Sidebar.handle
        height: parent.height
        color: mouse.containsMouse || mouse.pressed ? Theme.accent : "transparent"

        MouseArea {
            id: mouse

            // Pointer offset from the handle edge at the moment of the grab
            property real grab: 0

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true
            onPressed: event => grab = event.x
            onPositionChanged: event => {
                if (!pressed)
                    return;
                const edge = mapToItem(null, event.x, 0).x - grab + handle.width / 2;
                const width = Math.round(panel.width - edge);
                Sidebar.setWidth(panel.screen, Math.max(Sidebar.minWidth, Math.min(Sidebar.maxWidth(panel.screen), width)));
            }
            onReleased: Sidebar.save()
        }
    }
}
