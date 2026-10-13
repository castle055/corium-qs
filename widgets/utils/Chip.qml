import QtQuick

// A button that can be shown as selected, for picking one of several options
// (filters, sort orders, presets).
Rectangle {
    id: chip

    property alias text: label.text
    property bool selected: false
    property int textSize: 14
    // Background when not selected; lighter on cards that are already #1c1c1c.
    property color idleColor: "#1c1c1c"

    signal clicked()

    implicitWidth: Math.max(64, label.implicitWidth + 24)
    implicitHeight: 44
    radius: 10

    color: mouse.pressed ? "#404040" : selected ? "#203040" : idleColor
    border.width: selected ? 1 : 0
    border.color: "#80bfff"

    Text {
        id: label

        anchors.centerIn: parent
        color: chip.selected ? "#80bfff" : "white"
        font.pixelSize: chip.textSize
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        onClicked: chip.clicked()
    }
}
