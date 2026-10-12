import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower
import "utils"

BarPopupButton {
    id: root

    implicitWidth: 60
    implicitHeight: 48

    // UPower's default device can temporarily be unready, so guard it.
    property var battery: UPower.displayDevice

    property real percentage:
    battery && battery.ready
    ? battery.percentage*100
    : 0

    property bool charging:
    battery && battery.ready
    ? battery.state === UPowerDeviceState.Charging ||
    battery.state === UPowerDeviceState.PendingCharge
    : false

    property bool fullyCharged:
    battery && battery.ready
    ? battery.state === UPowerDeviceState.FullyCharged
    : false

    property bool lowBattery:
    percentage <= 20 && !charging

    property bool criticalBattery:
    percentage <= 10 && !charging

    // ------------------------------------------------------------------
    // Battery icon
    // ------------------------------------------------------------------

    Row {
        anchors.centerIn: parent

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (root.charging)
                return "󰂄 "

                if (root.fullyCharged)
                return " "

                if (root.percentage >= 90)
                return "󰁹 "
                if (root.percentage >= 80)
                return "󰂂 "
                if (root.percentage >= 60)
                return "󰂀 "
                if (root.percentage >= 40)
                return "󰁾 "
                if (root.percentage >= 20)
                return "󰁼 "

                return "󰁺 "
            }

            color: {
                if (root.criticalBattery)
                return "#ff5555"

                if (root.lowBattery)
                return "#ffaa00"

                return "white"
            }

            font.pixelSize: 18
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.battery && root.battery.ready
            ? Math.round(root.percentage) + "%"
            : "--%"

            color: "white"
            font.pixelSize: 10
        }
    }

    // ------------------------------------------------------------------
    // Popup
    // ------------------------------------------------------------------

    popup: Rectangle {
        width: 400
        height: 240
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.margins: 18

            spacing: 14

            // ------------------------------------------------------
            // Battery header
            // ------------------------------------------------------

            Row {
                width: parent.width
                spacing: 12

                Text {
                    text: root.charging
                    ? "󰂄"
                    : "󰁹"

                    color: root.criticalBattery
                    ? "#ff5555"
                    : "white"

                    font.pixelSize: 32

                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2

                    Text {
                        text: root.battery && root.battery.ready
                        ? Math.round(root.percentage) + "%"
                        : "--%"

                        color: "white"
                        font.pixelSize: 24
                    }

                    Text {
                        text: {
                            if (!root.battery || !root.battery.ready)
                            return "Battery unavailable"

                            if (root.fullyCharged)
                                return "Fully charged"

                            if (root.charging)
                                return formatTime(
                                            root.battery.timeToFull
                                            ) + " until full"

                            if (root.battery.timeToEmpty > 0)
                                return formatTime(root.battery.timeToEmpty )
                                        + " remaining from "
                                        + formatTime(root.battery.timeToEmpty*100/root.percentage)
                                                     + " total"

                            return "Discharging"
                        }

                        color: "#aaaaaa"
                        font.pixelSize: 12
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#404040"
            }

            // ------------------------------------------------------
            // Battery level
            // ------------------------------------------------------

            Text {
                text: "Battery"
                color: "#aaaaaa"
                font.pixelSize: 12
            }

            Rectangle {
                width: parent.width
                height: 8

                radius: 4
                color: "#353535"

                Rectangle {
                    width: parent.width *
                    Math.max(0, Math.min(1, root.percentage / 100))

                    height: parent.height
                    radius: parent.radius

                    color: root.criticalBattery
                    ? "#ff5555"
                    : root.lowBattery
                    ? "#ffaa00"
                    : "#ffffff"
                }
            }

            // ------------------------------------------------------
            // CPU power profile
            // ------------------------------------------------------

            Text {
                text: "Performance profile"
                color: "#aaaaaa"
                font.pixelSize: 12
            }

            Row {
                width: parent.width
                height: 40

                spacing: 6

                ProfileButton {
                    width: (parent.width - 12) / 3
                    height: parent.height

                    visible: true

                    icon: "󰾆"
                    label: "Power saver"

                    selected:
                    PowerProfiles.profile ===
                    PowerProfile.PowerSaver

                    onClicked: {
                        PowerProfiles.profile =
                        PowerProfile.PowerSaver
                    }
                }

                ProfileButton {
                    width: (parent.width - 12) / 3
                    height: parent.height

                    icon: "󰗑"
                    label: "Balanced"

                    selected:
                    PowerProfiles.profile ===
                    PowerProfile.Balanced

                    onClicked: {
                        PowerProfiles.profile =
                        PowerProfile.Balanced
                    }
                }

                ProfileButton {
                    width: (parent.width - 12) / 3
                    height: parent.height

                    visible: PowerProfiles.hasPerformanceProfile

                    icon: "󰓅"
                    label: "Performance"

                    selected:
                    PowerProfiles.profile ===
                    PowerProfile.Performance

                    onClicked: {
                        if (PowerProfiles.hasPerformanceProfile)
                        PowerProfiles.profile =
                        PowerProfile.Performance
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Helper component for power-profile buttons
    // ------------------------------------------------------------------

    component ProfileButton: Rectangle {
        property string icon
        property string label
        property bool selected: false

        signal clicked()

        radius: 6

        color: selected
        ? "#505050"
        : mouse.containsMouse
        ? "#353535"
        : "#292929"

        border.width: selected ? 1 : 0
        border.color: "#777777"

        MouseArea {
            id: mouse

            anchors.fill: parent

            hoverEnabled: true

            onClicked: parent.clicked()
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: parent.parent.icon

                color: "white"
                font.pixelSize: 16
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: parent.parent.label

                color: "#bbbbbb"
                font.pixelSize: 9
            }
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
        return "--"

        const minutes = Math.round(seconds / 60)
        const hours = Math.floor(minutes / 60)
        const mins = minutes % 60

        if (hours > 0)
        return hours + "h " + mins + "m"

        return mins + "m"
    }
}
