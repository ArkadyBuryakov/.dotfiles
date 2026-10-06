import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.bg

    // Matched by the blur layer rule in hypr/conf/visuals.lua
    WlrLayershell.namespace: "quickshell-bar"

    Workspaces {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 3
        height: parent.height - 6
        screen: bar.screen
    }

    Row {
        anchors.centerIn: parent

        // Module {
        //     text: Polls.anki.text
        //     tooltip: Polls.anki.tooltip
        //     color: Polls.anki.cls === "due" ? Theme.warning : Theme.fg
        //     onClicked: Quickshell.execDetached(["anki"])
        // }
        Clock {}
    }

    Row {
        anchors.right: parent.right

        Module {
            text: Polls.dnd.text
            tooltip: Polls.dnd.tooltip
            color: Polls.dnd.cls === "active" ? Theme.alert : Theme.fg
            onClicked: Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/toggle_dnd.sh"])
        }
        // Module {
        //     text: Polls.clamav.text
        //     tooltip: Polls.clamav.tooltip
        //     color: Polls.clamav.cls === "threat" ? Theme.alert : Polls.clamav.cls === "stale" ? Theme.warning : Theme.fg
        //     onClicked: Quickshell.execDetached(["kitty", "-T", "Antivirus", "/etc/clamav/threat-manager.sh"])
        // }
        Module {
            name: "keyboard"
            text: Keyboard.layout
            onClicked: Keyboard.next()
        }
        Module {
            name: "cpu"
            text: `\u{F4BC} ${SysStats.cpu}%`
            card: SysCard {}
            onClicked: Quickshell.execDetached(["kitty", Quickshell.shellPath("scripts/btop-sorted.sh"), "cpu lazy"])
        }
        Module {
            name: "memory"
            text: `\u{E266} ${SysStats.memory}%`
            card: SysCard {}
            onClicked: Quickshell.execDetached(["kitty", Quickshell.shellPath("scripts/btop-sorted.sh"), "memory"])
        }
        Volume {}
        Network {}
        Bluetooth {}
        Battery {}
        Power {}
    }
}
