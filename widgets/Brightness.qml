import QtQuick
import Quickshell
import Quickshell.Io
import "utils"

BarPopupButton {
    id: root

    property int brightness: 0
    property int maximum: 100

    readonly property int percent: Math.round(root.brightness / root.maximum * 100)

    implicitWidth: 60
    implicitHeight: 48

    Process {
        id: getBrightness

        command: ["brightnessctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim())
                // Ignore polls while dragging so the slider doesn't jump back.
                if (!isNaN(value) && !brightnessSlider.pressed)
                    root.brightness = value
            }
        }
    }

    Process {
        id: getMaximum

        command: ["brightnessctl", "max"]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim())
                if (!isNaN(value))
                    root.maximum = value
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: {
            getBrightness.running = true
        }
    }

    // Rate-limit brightnessctl calls while the slider is being dragged.
    property int pendingPercent: -1

    Timer {
        id: applyTimer
        interval: 40

        onTriggered: {
            if (root.pendingPercent < 0)
                return
            Quickshell.execDetached([
                "brightnessctl",
                "--min-value=5",
                "set",
                root.pendingPercent + "%"
            ])
            root.pendingPercent = -1
        }
    }

    function setPercent(value) {
        value = Math.max(1, Math.min(100, Math.round(value)))
        root.brightness = Math.round(value / 100 * root.maximum)
        root.pendingPercent = value
        if (!applyTimer.running)
            applyTimer.start()
    }

    Row {
        anchors.centerIn: parent

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: "󰃠 "

            color: "white"
            font.pixelSize: 18
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.percent + "%"

            color: "white"
            font.pixelSize: 10
        }
    }

    property var wheelAccumulator: 0

    MouseArea {
        anchors.fill: parent

        onWheel: wheel => {
            if (root.wheelAccumulator * wheel.angleDelta.y < 0) {
                // Reset accumulator if changing scroll direction
                root.wheelAccumulator = 0
            }
            root.wheelAccumulator += wheel.angleDelta.y

            if (root.wheelAccumulator >= 100) {
                incBrightness(10)
                root.wheelAccumulator = 0
            }
            if (root.wheelAccumulator <= -100) {
                decBrightness(10)
                root.wheelAccumulator = 0
            }
            getBrightness.running = true
        }

        onClicked: {
            root.popupVisible = true
            getBrightness.running = true
        }
    }

    function incBrightness(value) {
        let new_value = (100 * root.brightness / root.maximum) + value;
        new_value = new_value - (new_value % 10)
        Quickshell.execDetached([
            "brightnessctl",
            "--min-value=5",
            "set",
            new_value + "%"
        ])

        getBrightness.running = true
    }

    function decBrightness(value) {
        let new_value = (100 * root.brightness / root.maximum) - value;
        new_value = new_value - (new_value % 10)
        Quickshell.execDetached([
            "brightnessctl",
            "--min-value=5",
            "set",
            new_value + "%"
        ])

        getBrightness.running = true
    }

    Component.onCompleted: {
        getMaximum.running = true
        getBrightness.running = true
    }

    popup: Rectangle {
        implicitWidth: 400
        implicitHeight: 74
        color: "transparent"

        FillSlider {
            id: brightnessSlider

            anchors.fill: parent
            anchors.margins: 16

            from: 1
            to: 100
            stepSize: 1

            value: root.percent

            icon: "󰃠"
            label: Math.round(value) + "%"

            onMoved: root.setPercent(value)
        }
    }
}
