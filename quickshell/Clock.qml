import QtQuick
import Quickshell
import Quickshell.Io

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

    // The clock's timer runs on the monotonic clock, which stops during suspend,
    // so re-read the time when logind reports a resume
    Process {
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("PrepareForSleep (false")) {
                    clock.enabled = false;
                    clock.enabled = true;
                }
            }
        }
    }
}
