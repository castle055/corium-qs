pragma ComponentBehavior: Bound

import QtQuick
import "../../services"

// A stopwatch with laps.
Column {
    id: page

    // Only redraw the running time while the page can be seen.
    property bool active: true

    spacing: 14

    property real now: Date.now()
    readonly property real elapsed: Stopwatch.elapsed(now)

    // Lap times (not totals), oldest first.
    readonly property var lapTimes: Stopwatch.laps.map((total, i) => total - (i > 0 ? Stopwatch.laps[i - 1] : 0))
    readonly property real fastest: lapTimes.length >= 2 ? Math.min(...lapTimes) : -1
    readonly property real slowest: lapTimes.length >= 2 ? Math.max(...lapTimes) : -1

    function icon(codepoint) {
        return String.fromCodePoint(codepoint)
    }

    onActiveChanged: now = Date.now()

    Timer {
        interval: 10
        repeat: true
        running: page.active && Stopwatch.running
        onTriggered: page.now = Date.now()
        onRunningChanged: page.now = Date.now()
    }

    // Time

    Item {
        width: parent.width
        height: 88

        Text {
            anchors.centerIn: parent

            text: Stopwatch.format(page.elapsed)
            color: Stopwatch.running || !Stopwatch.started ? "white" : "#aaaaaa"
            font.pixelSize: 48
            font.bold: true
            font.features: { "tnum": 1 }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

            visible: Stopwatch.laps.length > 0
            text: "Lap " + (Stopwatch.laps.length + 1) + "  "
                  + Stopwatch.format(page.elapsed - Stopwatch.laps[Stopwatch.laps.length - 1])
            color: "#aaaaaa"
            font.pixelSize: 14
            font.features: { "tnum": 1 }
        }
    }

    // Lap / Reset and Start / Pause

    Item {
        width: parent.width
        height: 72

        RoundButton {
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.verticalCenter: parent.verticalCenter

            enabled: Stopwatch.started
            label: Stopwatch.running ? "Lap" : "Reset"
            onClicked: Stopwatch.running ? Stopwatch.lap() : Stopwatch.reset()
        }

        RoundButton {
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.verticalCenter: parent.verticalCenter

            primary: !Stopwatch.running
            label: Stopwatch.running ? "Pause" : Stopwatch.started ? "Resume" : "Start"
            onClicked: Stopwatch.running ? Stopwatch.pause() : Stopwatch.start()
        }
    }

    // Laps, newest first. The fastest is green and the slowest red.

    Rectangle {
        width: parent.width
        height: 1
        color: "#404040"
        visible: lapList.count > 0
    }

    ListView {
        id: lapList

        width: parent.width
        height: Math.min(contentHeight, 6 * 40)
        visible: count > 0

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        model: page.lapTimes.length

        delegate: Item {
            id: lapRow

            required property int index

            // Newest first.
            readonly property int number: page.lapTimes.length - index
            readonly property real time: page.lapTimes[number - 1]
            readonly property color tint: time === page.fastest
                                          ? "#77dd77"
                                          : time === page.slowest ? "#ff7777" : "white"

            width: lapList.width
            height: 40

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                text: "Lap " + lapRow.number
                color: lapRow.tint
                font.pixelSize: 14
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                text: Stopwatch.format(lapRow.time)
                color: lapRow.tint
                font.pixelSize: 14
                font.bold: true
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                text: Stopwatch.format(Stopwatch.laps[lapRow.number - 1])
                color: "#777777"
                font.pixelSize: 13
                font.features: { "tnum": 1 }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#262626"
            }
        }
    }

    component RoundButton: Rectangle {
        id: button

        property string label
        property bool primary: false

        signal clicked()

        width: 72
        height: 72
        radius: width / 2
        opacity: enabled ? 1 : 0.4

        color: primary
               ? (buttonMouse.pressed ? "#99ccff" : "#80bfff")
               : (buttonMouse.pressed ? "#404040" : "#262626")

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.primary ? "#202020" : "white"
            font.pixelSize: 15
            font.bold: true
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            onClicked: button.clicked()
        }
    }
}
