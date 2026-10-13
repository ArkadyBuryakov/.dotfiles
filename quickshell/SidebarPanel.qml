import QtQuick
import Quickshell
import Quickshell.Wayland

// The strip a docked window (see Sidebar.qml) sits on. It is invisible, tabs
// aside (what an empty strip shows is SidebarBackdrop, under the windows), and
// does four things: its exclusive zone keeps tiled windows out of
// the strip, a handle over its inner edge drags the width, tabs above the
// window switch between the windows of the sidebar when it holds several, and
// it takes the pointer input around the window, where Hyprland would otherwise
// start a border resize (general.resize_on_border).
PanelWindow {
    id: panel

    required property ShellScreen modelData

    readonly property int stripWidth: Sidebar.stripWidth(modelData)
    readonly property int tabHeight: Sidebar.tabs(modelData.name)

    screen: modelData
    visible: Sidebar.isOpen(modelData.name)
    anchors {
        top: true
        bottom: true
        right: true
    }
    // The surface always spans the widest possible strip (plus the part of the
    // handle that sticks out of it), so that it does not resize under the
    // pointer while the handle is dragged.
    implicitWidth: Sidebar.maxWidth(modelData) + Sidebar.grabArea
    exclusiveZone: stripWidth
    color: "transparent"
    mask: Region {
        item: handle

        Region {
            item: frame
        }
        // Hand the pointer back inside the frame, to the window itself
        Region {
            item: content
            intersection: Intersection.Subtract
        }
    }

    // Same layer as the bar: exclusive zones are handed out layer by layer,
    // and from a lower one the strip would cut the bar short.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-sidebar"

    onStripWidthChanged: resize.start()
    onTabHeightChanged: resize.start()
    onVisibleChanged: resize.start()
    // The monitor changed its mode or scale
    onWidthChanged: resize.start()
    onHeightChanged: resize.start()

    // Follow the handle at ~30 updates a second
    Timer {
        id: resize
        interval: 33
        onTriggered: Sidebar.apply(panel.screen.name)
    }

    // The tabs, the docked window and its border
    Item {
        id: frame

        x: panel.width - panel.stripWidth
        width: panel.stripWidth
        height: parent.height

        Item {
            id: content

            anchors.fill: parent
            anchors.margins: Sidebar.border
            anchors.topMargin: Sidebar.border + panel.tabHeight
        }

        Row {
            width: parent.width
            height: panel.tabHeight
            visible: panel.tabHeight > 0

            Repeater {
                model: Sidebar.windows(panel.modelData.name)

                SidebarTab {
                    width: frame.width / Sidebar.windows(panel.modelData.name).length
                    height: panel.tabHeight
                    active: modelData === Sidebar.active(panel.modelData.name)
                }
            }
        }
    }

    // Covers the inner border of the window and its whole grab area
    MouseArea {
        id: handle

        // Pointer offset from the strip edge at the moment of the grab
        property real offset: 0

        x: frame.x - Sidebar.grabArea
        width: Sidebar.grabArea + Sidebar.border
        height: parent.height
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        preventStealing: true
        onPressed: event => offset = event.x - Sidebar.grabArea
        onPositionChanged: event => {
            if (!pressed)
                return;
            const edge = mapToItem(null, event.x, 0).x - offset;
            const width = Math.round(panel.width - edge);
            Sidebar.setWidth(panel.screen, Math.max(Sidebar.minWidth, Math.min(Sidebar.maxWidth(panel.screen), width)));
        }
        onReleased: Sidebar.save()

        Rectangle {
            x: Sidebar.grabArea - width / 2
            width: Sidebar.handle
            height: parent.height
            color: Theme.accent
            visible: handle.containsMouse || handle.pressed
        }
    }
}
