pragma ComponentBehavior: Bound

import QtQuick
import "utils"
import "sysmon"
import "../services"

// CPU, memory and swap as three small bars, filled from the bottom. They keep
// their colour while things are fine and turn amber, then red, when the
// system is running short. Opens graphs, processes and services.
BarPopupButton {
    id: root

    property var screen

    implicitWidth: content.implicitWidth + 24
    implicitHeight: 48

    fullHeight: true
    // The pages have filter fields.
    keyboardFocus: true

    readonly property color cpuColor: "#80bfff"
    readonly property color memoryColor: "#77dd77"
    readonly property color swapColor: "#c58aff"

    // "processes" or "services"
    property string page: "processes"

    function levelColor(percent, normal) {
        if (percent >= 95)
            return "#ff5555"
        if (percent >= 80)
            return "#ffaa00"
        return normal
    }

    // Like the other widgets: an icon followed by its value, here three small
    // bars (CPU, then memory and swap) drawn as one compact chart.
    Row {
        id: content

        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: String.fromCodePoint(0xF035B)
            color: "white"
            font.pixelSize: 18
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Meter {
                value: SystemStats.cpu
                fillColor: root.levelColor(SystemStats.cpu, root.cpuColor)
            }

            Meter {
                value: SystemStats.memory
                fillColor: root.levelColor(SystemStats.memory, root.memoryColor)
            }

            Meter {
                value: SystemStats.swap
                fillColor: root.levelColor(SystemStats.swap, root.swapColor)
            }
        }
    }

    popup: Item {
        implicitWidth: 560
        implicitHeight: root.screen ? root.screen.height - 48 : 800

        Item {
            anchors.fill: parent
            anchors.margins: 16

            // Graphs

            Row {
                id: graphs

                width: parent.width
                spacing: 12

                GraphCard {
                    width: (parent.width - 12) / 2
                    title: "CPU"
                    value: Math.round(SystemStats.cpu) + "%"
                    valueColor: root.levelColor(SystemStats.cpu, "white")
                    details: [{ color: root.cpuColor, text: SystemStats.cores + " cores" }]
                    series: [{ values: SystemStats.cpuHistory, color: root.cpuColor }]
                }

                GraphCard {
                    width: (parent.width - 12) / 2
                    title: "Memory"
                    value: Math.round(SystemStats.memory) + "%"
                    valueColor: root.levelColor(SystemStats.memory, "white")
                    details: [
                        { color: root.memoryColor,
                          text: SystemStats.formatBytes(SystemStats.memoryUsed) + " / "
                                + SystemStats.formatBytes(SystemStats.memoryTotal) },
                        { color: root.swapColor,
                          text: SystemStats.swapTotal > 0
                                ? "Swap " + SystemStats.formatBytes(SystemStats.swapUsed) + " / "
                                  + SystemStats.formatBytes(SystemStats.swapTotal)
                                : "No swap" },
                    ]
                    series: [
                        { values: SystemStats.swapHistory, color: root.swapColor },
                        { values: SystemStats.memoryHistory, color: root.memoryColor },
                    ]
                }
            }

            Text {
                id: graphCaption

                anchors.top: graphs.bottom
                anchors.topMargin: 4
                anchors.right: parent.right
                text: "Last " + Math.round(SystemStats.historyLength * SystemStats.interval / 60000) + " minutes"
                color: "#666666"
                font.pixelSize: 11
            }

            // Processes / Services switch

            Rectangle {
                id: tabs

                anchors.top: graphCaption.bottom
                anchors.topMargin: 10
                width: parent.width
                height: 44
                radius: 12
                color: "#1c1c1c"

                Row {
                    anchors.fill: parent
                    anchors.margins: 4

                    Repeater {
                        model: [
                            { page: "processes", label: "Processes" },
                            { page: "services", label: "Services" },
                        ]

                        delegate: Rectangle {
                            id: tab

                            required property var modelData
                            readonly property bool current: root.page === modelData.page

                            width: parent.width / 2
                            height: parent.height
                            radius: 9
                            color: current ? "#353535" : tabMouse.pressed ? "#262626" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: tab.modelData.label
                                color: tab.current ? "white" : "#aaaaaa"
                                font.pixelSize: 14
                                font.bold: tab.current
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                onClicked: root.page = tab.modelData.page
                            }
                        }
                    }
                }
            }

            ProcessesPage {
                anchors.top: tabs.bottom
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                width: parent.width

                visible: root.page === "processes"
                active: root.popupVisible && visible
            }

            ServicesPage {
                anchors.top: tabs.bottom
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                width: parent.width

                visible: root.page === "services"
                active: root.popupVisible && visible
            }
        }
    }

    // A thin capsule filled from the bottom.
    component Meter: Rectangle {
        id: meter

        property real value
        property color fillColor

        width: 5
        height: 18
        radius: 2
        color: "#333333"
        clip: true

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(meter.value > 0 ? width : 0, parent.height * Math.min(100, meter.value) / 100)
            radius: 2
            color: meter.fillColor

            Behavior on height {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 400 }
            }
        }
    }

    component GraphCard: Rectangle {
        id: card

        property string title
        property string value
        property color valueColor: "white"
        // [{ color, text }]
        property var details: []
        property alias series: graph.series

        height: 172
        radius: 12
        color: "#1c1c1c"

        Column {
            id: header

            x: 12
            y: 10
            width: parent.width - 24
            spacing: 2

            Item {
                width: parent.width
                height: valueText.height

                Text {
                    anchors.baseline: valueText.baseline
                    text: card.title
                    color: "#aaaaaa"
                    font.pixelSize: 13
                }

                Text {
                    id: valueText

                    anchors.right: parent.right
                    text: card.value
                    color: card.valueColor
                    font.pixelSize: 20
                    font.bold: true
                    font.features: { "tnum": 1 }
                }
            }

            Repeater {
                model: card.details

                delegate: Row {
                    required property var modelData
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: parent.modelData.color
                    }

                    Text {
                        text: parent.modelData.text
                        color: "#aaaaaa"
                        font.pixelSize: 11
                    }
                }
            }
        }

        Graph {
            id: graph

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            anchors.top: header.bottom
            anchors.topMargin: 8

            capacity: SystemStats.historyLength
        }
    }
}
