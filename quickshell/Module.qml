import QtQuick
import Quickshell
import Quickshell.Hyprland

// A bar item: a text label, with an optional hover card (`card`, or plain
// `tooltip` text) and an optional click menu. Hidden while its text is empty.
Item {
    id: root

    // Name for `qs ipc call bar toggle|peek <name>`
    property string name: ""
    property alias text: label.text
    property alias color: label.color
    property string tooltip: ""
    property Component card: null
    // Opened by a left click, which then no longer emits clicked()
    property Component menu: null

    readonly property bool menuOpen: Popups.active === root
    property bool peeked: false

    signal clicked
    signal rightClicked
    signal scrolled(bool up)

    visible: text !== ""
    implicitWidth: label.implicitWidth + 2 * Theme.padding
    implicitHeight: Theme.barHeight

    onVisibleChanged: {
        if (!visible && menuOpen)
            Popups.close();
    }
    Component.onDestruction: {
        if (menuOpen)
            Popups.close();
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.accent
        visible: root.menuOpen
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            root.peeked = false;
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else if (root.menu)
                Popups.toggle(root);
            else
                root.clicked();
        }
        onWheel: event => root.scrolled(event.angleDelta.y > 0)
        onContainsMouseChanged: {
            if (!containsMouse)
                root.peeked = false;
        }
    }

    Timer {
        interval: 400
        running: mouse.containsMouse && !root.peeked
        onTriggered: root.peeked = true
    }

    Popup {
        target: root
        open: root.peeked && Popups.active === null && (root.card !== null || root.tooltip !== "")
        content: root.card ?? textCard
    }

    Component {
        id: textCard

        Label {
            text: root.tooltip
        }
    }

    Popup {
        id: menuPopup
        target: root
        open: root.menuOpen
        content: root.menu
    }

    // Closes the menu on a click anywhere else. The bar is part of the grab so
    // that clicking a module still reaches it, to close this menu or swap it
    // for another.
    HyprlandFocusGrab {
        active: root.menuOpen
        windows: [menuPopup, root.QsWindow.window]
        onCleared: {
            if (root.menuOpen)
                Popups.close();
        }
    }

    Connections {
        target: Popups
        function onRequest(name, menu) {
            if (name !== root.name || !Hyprland.monitorFor(root.QsWindow.window.screen)?.focused)
                return;
            if (menu)
                Popups.toggle(root);
            else
                root.peeked = !root.peeked;
        }
    }
}
