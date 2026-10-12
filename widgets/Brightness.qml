import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int brightness: 0
    property int maximum: 100

    implicitWidth: 60
    implicitHeight: 48

    Process {
        id: getBrightness

        command: ["brightnessctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim())
                if (!isNaN(value))
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

    //Rectangle {
    //    anchors.fill: parent
    //    color: "red"
    //}

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
            text: Math.round(root.brightness / root.maximum * 100) +
            "%"

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
            // Nothing for now.
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
}
