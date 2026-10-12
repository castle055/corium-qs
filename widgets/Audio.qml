import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import "utils"

BarPopupButton {
    id: root

  //implicitWidth: {
  //    if (!root.sink || !root.sink.audio)
  //    return 60

  //    if (root.sink.audio.muted)
  //    return 70

  //    return 70
  //}
    implicitWidth: 60
    implicitHeight: 48

    // The currently active output device.
    property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [root.sink]
    }

    Row {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (!root.sink || !root.sink.audio)
                return "󰖁 "

                if (root.sink.audio.muted)
                return "󰖁 "

                return "󰕾 "
            }

            color: {
                if (root.sink.audio.muted)
                return "gray"

                return "white"
            }

            font.pixelSize: 18
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (!root.sink || !root.sink.audio)
                return "--"

                if (root.sink.audio.muted)
                return ""

                return Math.round(root.sink.audio.volume * 100) +
                "%"
            }

            color: "white"
            font.pixelSize: 10
        }
    }

    popup: Rectangle {
        implicitWidth: 400
        implicitHeight: 125
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // Volume

            Row {
                width: parent.width
                spacing: 10

                Text {
                    width: 45
                    text: root.sink && root.sink.audio
                    ? Math.round(root.sink.audio.volume * 100) + "%"
                    : "--"

                    color: "white"
                }

                Slider {
                    id: volumeSlider

                    width: parent.width - 55

                    from: 0
                    to: 1

                    value: root.sink && root.sink.audio
                    ? root.sink.audio.volume
                    : 0

                    onMoved: {
                        if (root.sink && root.sink.audio)
                        root.sink.audio.volume = value
                    }
                }
            }

            Text {
                text: "Output"
                color: "#aaaaaa"
                font.pixelSize: 12
            }

            // Output device selector

            ComboBox {
                id: sinkSelector

                width: parent.width

                model: {
                    return Pipewire.nodes.values.filter(
                        node => node.isSink && node.audio && !node.isStream && !node.description.includes("DisplayPort")
                    )
                }

                textRole: "nickname"

                currentIndex: {
                    const current = Pipewire.defaultAudioSink
                    if (!current)
                    return -1

                    return model.indexOf(current)
                }

                onActivated: index => {
                    const selected = model[index]

                    if (selected)
                    Pipewire.preferredDefaultAudioSink = selected
                }

                delegate: ItemDelegate {
                    width: sinkSelector.width

                    //text: modelData.description || modelData.nickname || modelData.name
                    text: modelData.nickname || modelData.name

                    highlighted: sinkSelector.highlightedIndex === index
                }
            }
        }
    }
}
//Item {
//    id: root
//
//    implicitWidth: {
//            if (!root.sink || !root.sink.audio)
//            return 60
//
//            if (root.sink.audio.muted)
//            return 70
//
//            return 70
//    }
//    implicitHeight: 48
//
//    property bool popupVisible: false
//
//    // The currently active output device.
//    property var sink: Pipewire.defaultAudioSink
//
//    PwObjectTracker {
//        objects: [root.sink]
//    }
//
//  //Rectangle {
//  //    //anchors.fill: parent
//  //    anchors.centerIn: parent
//  //    implicitHeight: 20
//  //    implicitWidth: 40
//  //    color: {
//  //        if (!root.sink || !root.sink.audio)
//  //        return "red"
//
//  //        if (root.sink.audio.muted)
//  //        return "#333333"
//
//  //        return "transparent"
//  //    }
//  //    radius: 13
//  //}
//    Rectangle {
//        width: parent.width
//        height: 30
//        anchors.verticalCenter: parent.verticalCenter
//        radius: 15
//        color: root.popupVisible? "#222222": "transparent"
//    }
//
//
//    Text {
//        anchors.centerIn: parent
//
//        text: {
//            if (!root.sink || !root.sink.audio)
//            return "󰖁  --"
//
//            if (root.sink.audio.muted)
//            return "󰖁"
//
//            return "󰕾  " +
//            Math.round(root.sink.audio.volume * 100) +
//            "%"
//        }
//
//        color: "transparent"
//        font.pointSize: 10
//    }
//
//
//    MouseArea {
//        anchors.fill: parent
//
//        hoverEnabled: true
//
//        onEntered: {
//        }
//
//        onExited: {
//        }
//
//        onClicked: {
//            root.popupVisible = true
//            //if (root.sink && root.sink.audio)
//            //root.sink.audio.muted = !root.sink.audio.muted
//        }
//
//        property var wheel_acc: 0
//
//        onWheel: wheel => {
//            if (!root.sink || !root.sink.audio)
//            return
//
//            if (wheel_acc * wheel.angleDelta.y < 0) {
//                // Reset accumulator if changing scroll direction
//                wheel_acc = 0
//            }
//            wheel_acc += wheel.angleDelta.y
//
//            if (wheel_acc >= 100) {
//                root.sink.audio.volume = Math.min(1.0, root.sink.audio.volume + 0.05)
//                wheel_acc = 0
//            }
//            if (wheel_acc <= -100) {
//                root.sink.audio.volume = Math.max(0.0, root.sink.audio.volume - 0.05)
//                wheel_acc = 0
//            }
//        }
//    }
//
//    OrganicPopUp {
//        id: popup
//        visible: root.popupVisible
//        onDismissed: root.popupVisible = false
//
//        Rectangle {
//            width: 400
//            height: 125
//            color: "transparent"
//
//            Column {
//                anchors.fill: parent
//                anchors.margins: 16
//                spacing: 12
//
//                // Volume
//
//                Row {
//                    width: parent.width
//                    spacing: 10
//
//                    Text {
//                        width: 45
//                        text: root.sink && root.sink.audio
//                        ? Math.round(root.sink.audio.volume * 100) + "%"
//                        : "--"
//
//                        color: "white"
//                    }
//
//                    Slider {
//                        id: volumeSlider
//
//                        width: parent.width - 55
//
//                        from: 0
//                        to: 1
//
//                        value: root.sink && root.sink.audio
//                        ? root.sink.audio.volume
//                        : 0
//
//                        onMoved: {
//                            if (root.sink && root.sink.audio)
//                            root.sink.audio.volume = value
//                        }
//                    }
//                }
//
//                Text {
//                    text: "Output"
//                    color: "#aaaaaa"
//                    font.pixelSize: 12
//                }
//
//                // Output device selector
//
//                ComboBox {
//                    id: sinkSelector
//
//                    width: parent.width
//
//                    model: {
//                        return Pipewire.nodes.values.filter(
//                            node => node.isSink && node.audio && !node.isStream && !node.description.includes("DisplayPort")
//                        )
//                    }
//
//                    textRole: "nickname"
//
//                    currentIndex: {
//                        const current = Pipewire.defaultAudioSink
//                        if (!current)
//                        return -1
//
//                        return model.indexOf(current)
//                    }
//
//                    onActivated: index => {
//                        const selected = model[index]
//
//                        if (selected)
//                        Pipewire.preferredDefaultAudioSink = selected
//                    }
//
//                    delegate: ItemDelegate {
//                        width: sinkSelector.width
//
//                        //text: modelData.description || modelData.nickname || modelData.name
//                        text: modelData.nickname || modelData.name
//
//                        highlighted: sinkSelector.highlightedIndex === index
//                    }
//                }
//            }
//        }
//    }
//}
