import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

// Click: output and input device selector with volume. Right click: mute. Scroll: 1% steps.
Module {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool sourceMuted: source?.audio?.muted ?? false
    readonly property list<string> icons: ["\u{F026} ", "\u{F027} ", "\u{F028} "]
    readonly property string icon: muted ? "\u{EEE8} " : icons[Math.min(icons.length - 1, Math.floor(volume * icons.length))]

    // Names of nodes whose ports are all unplugged (e.g. HDMI with no display).
    // PwNode doesn't expose port availability, so it comes from pactl.
    property var unavailable: []

    function selectable(n, sink) {
        return n.audio && !n.isStream && n.isSink === sink && !unavailable.includes(n.name);
    }

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

    // Device selector plus a volume row with a mute button on the icon
    component DeviceControl: ColumnLayout {
        id: section

        property string title
        property PwNode node
        property var devices: []
        property string icon
        property bool expanded: false

        readonly property real volume: node?.audio?.volume ?? 0
        readonly property bool muted: node?.audio?.muted ?? false

        signal selected(PwNode device)

        function name(n) {
            return n?.nickname || n?.description || n?.name || "None";
        }

        Layout.preferredWidth: 320
        spacing: 2

        Heading {
            Layout.leftMargin: Theme.padding
            Layout.bottomMargin: 4
            text: section.title
        }
        MenuItem {
            text: section.name(section.node)
            detail: section.devices.length > 1 ? (section.expanded ? "\u{F0143}" : "\u{F0140}") : ""
            onClicked: section.expanded = !section.expanded && section.devices.length > 1
        }
        Repeater {
            model: section.expanded ? section.devices : []

            MenuItem {
                required property PwNode modelData
                readonly property bool current: modelData === section.node

                Layout.leftMargin: Theme.padding
                icon: current ? "\u{F012C}" : ""
                iconColor: Theme.good
                text: section.name(modelData)
                onClicked: {
                    section.selected(modelData);
                    section.expanded = false;
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            enabled: section.node?.audio != null
            opacity: enabled ? 1 : 0.5

            IconButton {
                icon: section.icon
                iconColor: section.muted ? Theme.alert : Theme.text
                onClicked: section.node.audio.muted = !section.muted
            }
            Slider {
                Layout.fillWidth: true
                value: section.volume
                fill: section.muted ? Theme.grey : Theme.accent
                onMoved: value => section.node.audio.volume = value
            }
            Label {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round(section.volume * 100) + "%"
            }
        }
    }

    menu: ColumnLayout {
        Component.onCompleted: ports.running = true

        spacing: 2

        DeviceControl {
            title: "Output"
            node: root.sink
            devices: Pipewire.nodes.values.filter(n => root.selectable(n, true))
            icon: root.icon
            onSelected: device => Pipewire.preferredDefaultAudioSink = device
        }
        DeviceControl {
            Layout.topMargin: 10
            title: "Input"
            node: root.source
            devices: Pipewire.nodes.values.filter(n => root.selectable(n, false))
            icon: root.sourceMuted ? "\u{F036D}" : "\u{F036C}"
            onSelected: device => Pipewire.preferredDefaultAudioSource = device
        }
    }

    Process {
        id: ports
        command: ["sh", "-c", 'printf "[%s,%s]" "$(pactl -f json list sinks)" "$(pactl -f json list sources)"']
        stdout: StdioCollector {
            onStreamFinished: {
                let lists = [[], []];
                try {
                    lists = JSON.parse(text);
                } catch (e) {}
                root.unavailable = [].concat(...lists)
                    .filter(d => d.ports.length > 0 && d.ports.every(p => p.availability === "not available"))
                    .map(d => d.name);
            }
        }
    }

    // Node properties are only populated while the node is tracked
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
