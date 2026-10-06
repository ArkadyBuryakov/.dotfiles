import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Click: volume slider. Right click: mute. Scroll: 1% steps.
Module {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property list<string> icons: ["\u{F026} ", "\u{F027} ", "\u{F028} "]
    readonly property string icon: muted ? "\u{EEE8} " : icons[Math.min(icons.length - 1, Math.floor(volume * icons.length))]

    function setVolume(value) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !muted;
    }

    name: "volume"
    text: icon
    tooltip: muted ? "Muted" : Math.round(volume * 100) + "%"

    onRightClicked: toggleMute()
    onScrolled: up => setVolume(volume + (up ? 0.01 : -0.01))

    menu: ColumnLayout {
        spacing: 4

        Heading {
            Layout.fillWidth: true
            Layout.maximumWidth: slider.implicitWidth + 80
            text: root.sink?.description || root.sink?.name || "No output"
            elide: Text.ElideRight
        }
        RowLayout {
            spacing: 8

            IconButton {
                icon: root.icon
                iconColor: root.muted ? Theme.alert : Theme.text
                onClicked: root.toggleMute()
            }
            Slider {
                id: slider
                value: root.volume
                fill: root.muted ? Theme.grey : Theme.accent
                onMoved: value => root.setVolume(value)
            }
            Label {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.volume * 100) + "%"
            }
        }
    }

    // Node properties are only populated while the node is tracked
    PwObjectTracker {
        objects: [root.sink]
    }
}
