pragma Singleton

import QtQuick
import Quickshell

// Colours follow the rest of the rice: the kitty palette
// (kitty/themes/Neutron_custom.conf) and the rofi/mako window style - flat
// dark surface, 2px accent border, no rounding.
Singleton {
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int barHeight: 30
    // Horizontal padding on each side of a module / workspace button
    readonly property int padding: 10

    // Bar
    readonly property color fg: "white"
    readonly property color bg: Qt.rgba(0, 0, 0, 0.2)

    // Popups
    readonly property color popupBg: "#1B1D22"
    readonly property color text: "#E6E8EE"
    readonly property color dim: "#99E6E8EE"
    readonly property color surface: "#2E353D"
    readonly property int borderWidth: 2
    readonly property int popupPadding: 8
    readonly property int rowHeight: 30

    readonly property color accent: "#6A7B92"
    readonly property color grey: "#454B55"
    readonly property color alert: "#B53F36"
    readonly property color warning: "#DDB566"
    readonly property color good: "#5AB977"

    // Colour for a 0..1 load figure
    function level(value) {
        return value >= 0.85 ? alert : value >= 0.6 ? warning : accent;
    }
}
