import QtQuick
import QtQuick.Layouts

// Month calendar with navigation.
ColumnLayout {
    id: root

    required property date today

    readonly property var locale: Qt.locale()
    // First day of the month on display
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    // 0 = Sunday. Monday, whatever the locale says
    readonly property int weekStart: 1
    readonly property date gridStart: addDays(month, -((month.getDay() - weekStart + 7) % 7))

    function addDays(date, days) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
    }

    function shift(months) {
        month = new Date(month.getFullYear(), month.getMonth() + months, 1);
    }

    spacing: 4

    RowLayout {
        spacing: 0

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            text: root.locale.standaloneMonthName(root.month.getMonth()) + " " + root.month.getFullYear()
            font.bold: true
        }
        IconButton {
            icon: "\u{F0141}"
            onClicked: root.shift(-1)
        }
        IconButton {
            // Back to the current month
            icon: "\u{F0766}"
            onClicked: root.month = new Date(root.today.getFullYear(), root.today.getMonth(), 1)
        }
        IconButton {
            icon: "\u{F0142}"
            onClicked: root.shift(1)
        }
    }

    Grid {
        columns: 7

        Repeater {
            model: 7

            Label {
                required property int index

                width: 36
                height: 22
                horizontalAlignment: Text.AlignHCenter
                text: root.locale.dayName((root.weekStart + index) % 7, Locale.ShortFormat).slice(0, 2)
                color: Theme.dim
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Repeater {
            model: 42

            Rectangle {
                id: cell

                required property int index
                readonly property date day: root.addDays(root.gridStart, index)
                readonly property bool isToday: day.toDateString() === root.today.toDateString()
                readonly property bool inMonth: day.getMonth() === root.month.getMonth()
                readonly property bool weekend: day.getDay() === 0 || day.getDay() === 6

                width: 36
                height: 30
                color: isToday ? Theme.accent : "transparent"

                Label {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    color: cell.isToday ? Theme.text : cell.weekend ? Theme.dim : Theme.text
                    opacity: cell.inMonth || cell.isToday ? 1 : 0.35
                    font.bold: cell.isToday
                }
            }
        }
    }
}
