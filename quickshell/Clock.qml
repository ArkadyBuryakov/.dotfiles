import QtQuick
import Quickshell

// Click: month calendar.
Module {
    id: root

    readonly property date now: clock.date
    readonly property var locale: Qt.locale()

    name: "clock"
    text: "\u{F43A}  " + locale.toString(now, "HH:mm") + "   \u{EAB0} " + locale.toString(now, "ddd, dd MMM yyyy")

    menu: Calendar {
        today: root.now
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
