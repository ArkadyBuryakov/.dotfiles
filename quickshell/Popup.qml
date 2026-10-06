import QtQuick
import Quickshell

// Framed popup shown just below `target`. `content` is instantiated only
// while the popup is open.
PopupWindow {
    id: root

    required property Item target
    property Component content: null
    property bool open: false

    // Distance from the bar. Hyprland itself keeps popups about as far from
    // the screen edge.
    readonly property int gap: 4

    anchor.item: target
    anchor.rect.x: target.width / 2
    anchor.rect.y: target.height + gap
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.SlideX

    visible: open && loader.status === Loader.Ready
    implicitWidth: frame.width
    implicitHeight: frame.height
    color: "transparent"

    Rectangle {
        id: frame

        readonly property int inset: Theme.borderWidth + Theme.popupPadding

        width: loader.implicitWidth + 2 * inset
        height: loader.implicitHeight + 2 * inset
        color: Theme.popupBg
        border.width: Theme.borderWidth
        border.color: Theme.accent

        Loader {
            id: loader
            x: frame.inset
            y: frame.inset
            active: root.open
            sourceComponent: root.content
        }
    }
}
