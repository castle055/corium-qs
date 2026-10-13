pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../../services"
import "../utils"

// Running timers, and a form to start a new one.
Column {
    id: page

    spacing: 14

    // The new timer's settings.
    property int hours: 0
    property int minutes: 5
    property int seconds: 0
    property bool sound: false
    readonly property int duration: ((hours * 60 + minutes) * 60 + seconds) * 1000

    readonly property var presets: [1, 3, 5, 10, 15, 30, 60]

    function icon(codepoint) {
        return String.fromCodePoint(codepoint)
    }

    function setDuration(ms) {
        const total = Math.round(ms / 1000)
        page.hours = Math.floor(total / 3600)
        page.minutes = Math.floor(total / 60) % 60
        page.seconds = total % 60
    }

    function startTimer() {
        Timers.start(page.duration, nameField.text.trim(), page.sound)
        nameField.text = ""
        nameField.focus = false
    }

    // Running timers

    Column {
        width: parent.width
        spacing: 8
        visible: Timers.active

        Repeater {
            model: Timers.timers

            delegate: Rectangle {
                id: card

                required property var modelData

                readonly property real remaining: Timers.remaining(modelData)
                readonly property bool warning: !modelData.paused && remaining <= Timers.warnThreshold(modelData)

                width: parent.width
                height: 76
                radius: 12
                color: "#1c1c1c"
                clip: true

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: buttons.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    spacing: 2

                    Text {
                        text: Timers.format(card.remaining)
                        color: card.modelData.paused ? "#aaaaaa" : card.warning ? "#ffaa00" : "white"
                        font.pixelSize: 26
                        font.bold: true
                        font.features: { "tnum": 1 }

                        Behavior on color {
                            ColorAnimation { duration: 400 }
                        }
                    }

                    Text {
                        width: parent.width
                        text: (card.modelData.label || Timers.describe(card.modelData.duration))
                              + (card.modelData.paused ? " · Paused" : "")
                              + (card.modelData.sound ? "  " + page.icon(0xF009A) : "")
                        color: "#aaaaaa"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: buttons

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    spacing: 6

                    Chip {
                        idleColor: "#262626"
                        textSize: 13
                        text: "+1 min"
                        onClicked: Timers.addTime(card.modelData.id, 60000)
                    }

                    Chip {
                        idleColor: "#262626"
                        width: 44
                        text: page.icon(card.modelData.paused ? 0xF040A : 0xF03E4)
                        textSize: 20
                        onClicked: card.modelData.paused
                                   ? Timers.resume(card.modelData.id)
                                   : Timers.pause(card.modelData.id)
                    }

                    Chip {
                        idleColor: "#262626"
                        width: 44
                        text: page.icon(0xF0156)
                        textSize: 20
                        onClicked: Timers.cancel(card.modelData.id)
                    }
                }

                // Progress
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.min(1, Timers.progress(card.modelData))
                    height: 4
                    color: card.warning ? "#ffaa00" : "#80bfff"
                    opacity: card.modelData.paused ? 0.4 : 1
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: "#404040"
        visible: Timers.active
    }

    Text {
        text: "New timer"
        color: "#aaaaaa"
        font.pixelSize: 13
    }

    // Duration: hours, minutes and seconds, each with big up/down buttons.

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        DurationField {
            unit: "h"
            value: page.hours
            maximum: 23
            onEdited: v => page.hours = v
        }

        Separator {}

        DurationField {
            unit: "min"
            value: page.minutes
            maximum: 59
            onEdited: v => page.minutes = v
        }

        Separator {}

        DurationField {
            unit: "s"
            value: page.seconds
            maximum: 59
            onEdited: v => page.seconds = v
        }
    }

    // Presets

    Flow {
        width: parent.width
        spacing: 8

        Repeater {
            model: page.presets

            delegate: Chip {
                required property int modelData

                idleColor: "#262626"
                textSize: 13
                width: (page.width - 3 * 8) / 4
                text: modelData < 60 ? modelData + " min" : modelData / 60 + " h"
                selected: page.duration === modelData * 60000
                onClicked: page.setDuration(modelData * 60000)
            }
        }
    }

    // Name

    InputField {
        id: nameField

        width: parent.width
        placeholderText: "Name (optional)"

        onAccepted: {
            if (page.duration > 0)
                page.startTimer()
        }
    }

    // Sound: the whole row toggles it.

    Rectangle {
        width: parent.width
        height: 48
        radius: 10
        color: soundMouse.pressed ? "#2a2a2a" : "#1c1c1c"

        Text {
            id: soundIcon

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter

            text: page.icon(page.sound ? 0xF009A : 0xF009B)
            color: page.sound ? "white" : "#777777"
            font.pixelSize: 18
        }

        Text {
            anchors.left: soundIcon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            text: "Play a sound when done"
            color: "white"
            font.pixelSize: 14
        }

        // The row's MouseArea below handles taps, including on the switch.
        Toggle {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            checked: page.sound
        }

        MouseArea {
            id: soundMouse

            anchors.fill: parent
            onClicked: page.sound = !page.sound
        }
    }

    // Start

    Rectangle {
        width: parent.width
        height: 48
        radius: 10

        enabled: page.duration > 0
        opacity: enabled ? 1 : 0.4
        color: startMouse.pressed ? "#99ccff" : "#80bfff"

        Text {
            anchors.centerIn: parent
            text: page.duration > 0 ? "Start " + Timers.describe(page.duration) + " timer" : "Start"
            color: "#202020"
            font.pixelSize: 15
            font.bold: true
        }

        MouseArea {
            id: startMouse

            anchors.fill: parent
            onClicked: page.startTimer()
        }
    }

    // A number with up/down buttons that wrap around and repeat while held.
    component DurationField: Column {
        id: field

        property int value
        property int maximum
        property string unit

        signal edited(int value)

        width: 76
        spacing: 2

        function step(delta) {
            field.edited((field.value + delta + field.maximum + 1) % (field.maximum + 1))
        }

        HoldButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: page.icon(0xF0143)
            onStep: field.step(1)
        }

        Item {
            width: parent.width
            height: 44

            Text {
                id: number

                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -unitText.width / 2

                text: String(field.value).padStart(2, "0")
                color: "white"
                font.pixelSize: 32
                font.bold: true
                font.features: { "tnum": 1 }
            }

            Text {
                id: unitText

                anchors.left: number.right
                anchors.leftMargin: 3
                anchors.baseline: number.baseline

                text: field.unit
                color: "#aaaaaa"
                font.pixelSize: 12
            }
        }

        HoldButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: page.icon(0xF0140)
            onStep: field.step(-1)
        }
    }

    component Separator: Text {
        height: 44 * 3 + 4
        verticalAlignment: Text.AlignVCenter
        text: ":"
        color: "#555555"
        font.pixelSize: 28
        font.bold: true
    }

    // Steps once when pressed, then keeps stepping while held.
    component HoldButton: Rectangle {
        id: holdButton

        property alias text: holdLabel.text
        signal step()

        width: 56
        height: 44
        radius: 10
        color: holdMouse.pressed ? "#404040" : "#1c1c1c"

        Text {
            id: holdLabel

            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 22
        }

        Timer {
            id: repeatTimer

            interval: 400
            repeat: true
            onTriggered: {
                interval = 90
                holdButton.step()
            }
        }

        MouseArea {
            id: holdMouse

            anchors.fill: parent

            onPressed: {
                holdButton.step()
                repeatTimer.interval = 400
                repeatTimer.start()
            }
            onReleased: repeatTimer.stop()
            onCanceled: repeatTimer.stop()
        }
    }
}
