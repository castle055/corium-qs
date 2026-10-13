import QtQuick
import QtQuick.Controls

// A single-line text field (search, filter, name, form input). The popup it's
// in needs `keyboardFocus: true` for it to take keyboard input.
TextField {
    id: field

    implicitHeight: 44
    leftPadding: 14
    rightPadding: 14

    font.pixelSize: 14
    color: "white"
    placeholderTextColor: "#777777"
    selectByMouse: true

    background: Rectangle {
        radius: 10
        color: "#1c1c1c"
        border.width: 1
        border.color: field.activeFocus ? "#80bfff" : "#333333"
    }
}
