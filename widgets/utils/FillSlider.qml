import QtQuick
import QtQuick.Controls

// A thick, fill-style slider: the whole bar is the touch target, so it can be
// tapped or dragged anywhere without aiming for a small handle.
Slider {
    id: slider

    property string icon: ""
    property string label: ""

    implicitHeight: 42
    live: true

    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding
        width: slider.availableWidth
        height: slider.availableHeight
        radius: height / 2
        color: "#404040"

        Rectangle {
            // Never narrower than the track is tall, so the rounded end stays round.
            width: Math.max(height, slider.visualPosition * parent.width)
            height: parent.height
            radius: height / 2
            color: slider.pressed ? "#99ccff" : "#80bfff"
        }
    }

    handle: Item {}

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter

        text: slider.icon
        color: "#202020"
        font.pixelSize: 18
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter

        text: slider.label
        color: "white"
        font.pixelSize: 13
    }
}
