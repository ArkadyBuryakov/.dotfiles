import QtQuick
import QtQuick.Layouts

// Hover card for the CPU and memory modules: per-core load plus totals.
ColumnLayout {
    id: root

    function gib(kb) {
        return (kb / 1048576).toFixed(1);
    }

    spacing: 6

    RowLayout {
        Heading {
            Layout.fillWidth: true
            text: "CPU"
        }
        Label {
            text: SysStats.cpu + "%"
        }
    }
    Meter {
        Layout.fillWidth: true
        value: SysStats.cpu / 100
        fill: Theme.level(value)
    }

    GridLayout {
        Layout.topMargin: 4
        columns: 2
        columnSpacing: 16
        rowSpacing: 4
        // Fill column by column, so cores read top to bottom
        flow: GridLayout.TopToBottom
        rows: Math.ceil(SysStats.cores.length / 2)

        Repeater {
            model: SysStats.cores

            RowLayout {
                id: core

                required property int index
                required property int modelData

                spacing: 8

                Label {
                    Layout.preferredWidth: 16
                    horizontalAlignment: Text.AlignRight
                    text: core.index
                    color: Theme.dim
                }
                Meter {
                    Layout.preferredWidth: 90
                    value: core.modelData / 100
                    fill: Theme.level(value)
                }
                Label {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: core.modelData + "%"
                }
            }
        }
    }

    RowLayout {
        Label {
            Layout.fillWidth: true
            text: "Load"
            color: Theme.dim
        }
        Label {
            text: SysStats.load
        }
    }

    RowLayout {
        Layout.topMargin: 8

        Heading {
            Layout.fillWidth: true
            text: "Memory"
        }
        Label {
            text: `${root.gib(SysStats.memUsed)} / ${root.gib(SysStats.memTotal)} GiB`
            color: Theme.dim
        }
        Label {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: SysStats.memory + "%"
        }
    }
    Meter {
        Layout.fillWidth: true
        value: SysStats.memUsed / SysStats.memTotal
        fill: Theme.level(value)
    }

    RowLayout {
        visible: SysStats.swapTotal > 0

        Label {
            Layout.fillWidth: true
            text: "Swap"
            color: Theme.dim
        }
        Label {
            text: `${root.gib(SysStats.swapUsed)} / ${root.gib(SysStats.swapTotal)} GiB`
        }
    }
}
