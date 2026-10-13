import QtQuick

// A round, borderless button showing a single glyph.
Rectangle {
    id: button

    property alias text: label.text
    property int textSize: 20

    signal clicked()

    implicitWidth: 44
    implicitHeight: 44
    radius: width / 2
    opacity: enabled ? 1 : 0.4

    color: mouse.pressed ? "#404040" : "transparent"

    Text {
        id: label

        anchors.centerIn: parent
        color: "white"
        font.pixelSize: button.textSize
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        onClicked: button.clicked()
    }
}
