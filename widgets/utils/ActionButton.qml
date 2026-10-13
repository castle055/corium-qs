import QtQuick

// A labelled button, as big as a finger. `primary` fills it with the accent
// colour; `danger` makes it red, for destructive actions.
Rectangle {
    id: button

    property alias text: label.text
    property bool primary: false
    property bool danger: false

    signal clicked()

    implicitWidth: Math.max(96, label.implicitWidth + 24)
    implicitHeight: 44
    radius: 10
    opacity: enabled ? 1 : 0.4

    color: mouse.pressed
           ? (danger ? "#5a2020" : primary ? "#99ccff" : "#404040")
           : (danger ? "#3a1a1a" : primary ? "#80bfff" : "#303030")

    Text {
        id: label

        anchors.centerIn: parent
        color: button.danger ? "#ff7777" : button.primary ? "#202020" : "white"
        font.pixelSize: 14
        font.bold: true
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        onClicked: button.clicked()
    }
}
