import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Module {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool low: !charging && !full && percent <= 20
    // Mice, keyboards, headsets... reporting their own charge
    readonly property var peripherals: UPower.devices.values
        .filter(d => !d.isLaptopBattery && !d.powerSupply && d.isPresent && d.type !== UPowerDeviceType.LinePower)

    readonly property list<string> chargingIcons: ["\u{F089C}", "\u{F0086}", "\u{F0087}", "\u{F0088}", "\u{F089D}",
        "\u{F0089}", "\u{F089E}", "\u{F008A}", "\u{F008B}", "\u{F0085}"]
    readonly property list<string> icons: ["\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}",
        "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"]

    function duration(seconds) {
        const minutes = Math.round(seconds / 60);
        return minutes >= 60 ? `${Math.floor(minutes / 60)}h ${minutes % 60}m` : `${minutes}m`;
    }

    readonly property string status: {
        if (!device)
            return "";
        if (charging && device.timeToFull > 0)
            return `Charging · ${duration(device.timeToFull)} until full`;
        if (device.state === UPowerDeviceState.Discharging && device.timeToEmpty > 0)
            return `On battery · ${duration(device.timeToEmpty)} left`;
        if (device.state === UPowerDeviceState.Discharging)
            return "On battery";
        if (device.state === UPowerDeviceState.PendingCharge)
            return "Plugged in, not charging";
        return UPowerDeviceState.toString(device.state);
    }

    name: "battery"
    // Machines without a battery simply have no battery module
    text: !device?.isLaptopBattery ? "" : full ? "\u{F0079}"
        : (charging ? chargingIcons : icons)[Math.min(9, Math.floor(percent / 10))]
    color: low ? Theme.alert : Theme.fg

    component Fact: RowLayout {
        property alias label: key.text
        property alias value: fact.text

        Label {
            id: key
            Layout.fillWidth: true
            color: Theme.dim
        }
        Label {
            id: fact
            Layout.leftMargin: 24
        }
    }

    card: ColumnLayout {
        spacing: 6

        RowLayout {
            Heading {
                Layout.fillWidth: true
                text: "Battery"
            }
            Label {
                text: root.percent + "%"
            }
        }
        Meter {
            Layout.fillWidth: true
            Layout.minimumWidth: 220
            value: root.percent / 100
            fill: root.low ? Theme.alert : root.charging || root.full ? Theme.good : Theme.accent
        }
        Label {
            text: root.status
        }
        Fact {
            Layout.topMargin: 4
            visible: Math.abs(root.device?.changeRate ?? 0) > 0.05
            label: root.charging ? "Charge rate" : "Power draw"
            value: Math.abs(root.device?.changeRate ?? 0).toFixed(1) + " W"
        }
        Fact {
            visible: (root.device?.energyCapacity ?? 0) > 0
            label: "Energy"
            value: `${(root.device?.energy ?? 0).toFixed(1)} / ${(root.device?.energyCapacity ?? 0).toFixed(1)} Wh`
        }
        Fact {
            visible: root.device?.healthSupported ?? false
            label: "Health"
            value: Math.round(root.device?.healthPercentage ?? 0) + "%"
        }

        Heading {
            Layout.topMargin: 8
            visible: root.peripherals.length > 0
            text: "Devices"
        }
        Repeater {
            model: root.peripherals

            Fact {
                required property UPowerDevice modelData

                label: modelData.model || UPowerDeviceType.toString(modelData.type)
                value: Math.round(modelData.percentage * 100) + "%"
            }
        }
    }
}
