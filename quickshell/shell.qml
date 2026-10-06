import QtQuick
import Quickshell

// One bar per monitor; bars come and go with the outputs.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
