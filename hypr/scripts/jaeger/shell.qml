// jaeger: side panel showing running AI agents across kitty windows.
// Click a card to navigate to the agent (workspace + os window + tab + window).
// Launch: jaeger.sh  |  toggle via keybind: jaeger.sh toggle
//
// One panel per monitor (Variants tracks monitor add/remove); reserves
// screen space via the layer-shell exclusive zone instead of overlaying.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    property var agents: []
    property bool shown: true
    readonly property string dir: Quickshell.env("HOME") + "/.config/hypr/scripts/jaeger"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property color bg: "#1b1d22"
    readonly property color borderActive: "#6a7a91"
    readonly property color borderInactive: "#595959"
    readonly property color fgPrimary: "#dcdfe4"
    readonly property color fgSecondary: "#7f848e"

    function statusColor(s) {
        switch (s) {
        case "busy": return "#e5c07b";
        case "idle": return "#98c379";
        case "waiting": return "#e06c75";
        default: return "#5c6370";
        }
    }

    function wsLabel(ws) {
        if (ws === undefined || ws === null) return "?";
        const s = String(ws);
        return s.startsWith("special:") ? "◈ " + s.slice(8) : "ws " + s;
    }

    function rescan() {
        if (!scanner.running) scanner.running = true;
    }

    Process {
        id: scanner
        command: [root.dir + "/scan.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.agents = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    // Poll for status/title changes (those emit no compositor events)
    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.rescan()
    }

    // Instant refresh on window/workspace churn
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "workspacev2":
            case "activespecialv2":
                debounce.restart();
            }
        }
    }
    Timer {
        id: debounce
        interval: 250
        onTriggered: root.rescan()
    }

    IpcHandler {
        target: "jaeger"
        function toggle(): void {
            root.shown = !root.shown;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.shown

            anchors {
                top: true
                bottom: true
                left: true
            }
            implicitWidth: 330
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "jaeger"
            // exclusionMode defaults to Auto: reserves the panel width,
            // pushing tiled windows aside instead of overlapping them

            Rectangle {
                anchors.fill: parent
                radius: 0
                color: root.bg
                border.color: root.borderInactive
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "JAEGER"
                            color: root.fgSecondary
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.agents.length + " agent" + (root.agents.length === 1 ? "" : "s")
                            color: root.fgSecondary
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                        }
                    }

                    Text {
                        visible: root.agents.length === 0
                        Layout.fillWidth: true
                        text: "No agents running"
                        color: root.fgSecondary
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: 20
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.agents
                        spacing: 4
                        clip: true

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index

                            width: ListView.view.width
                            height: cardContent.implicitHeight + 16
                            radius: 0
                            color: root.bg
                            border.color: hover.hovered ? root.borderActive : root.borderInactive
                            border.width: 2

                            HoverHandler {
                                id: hover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: Quickshell.execDetached([
                                    root.dir + "/focus.sh",
                                    String(card.modelData.kitty_pid),
                                    String(card.modelData.kitty_win_id),
                                    String(card.modelData.hypr_address ?? "")
                                ])
                            }

                            ColumnLayout {
                                id: cardContent
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 8
                                }
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: String(card.index + 1)
                                        color: root.borderActive
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                        font.bold: true
                                    }

                                    Rectangle {
                                        id: dot
                                        width: 10
                                        height: 10
                                        radius: 0
                                        color: root.statusColor(card.modelData.status)

                                        SequentialAnimation on opacity {
                                            running: card.modelData.status === "busy"
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.3; duration: 600 }
                                            NumberAnimation { to: 1.0; duration: 600 }
                                            onRunningChanged: if (!running) dot.opacity = 1
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: card.modelData.project ?? "?"
                                        color: root.fgPrimary
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        implicitWidth: wsText.implicitWidth + 10
                                        implicitHeight: wsText.implicitHeight + 4
                                        radius: 0
                                        color: "transparent"
                                        border.color: root.borderInactive
                                        border.width: 1
                                        Text {
                                            id: wsText
                                            anchors.centerIn: parent
                                            text: root.wsLabel(card.modelData.workspace)
                                            color: root.fgSecondary
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSize
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (card.modelData.agent ?? "?")
                                          + (card.modelData.branch ? "  ·  " + card.modelData.branch : "")
                                    color: root.fgSecondary
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: !!card.modelData.task
                                    text: card.modelData.task ?? ""
                                    color: root.fgSecondary
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
