import QtQuick

// An on/off switch. It doesn't change `checked` itself: handle `toggled` and
// update whatever `checked` is bound to.
Rectangle {
    id: toggle

    property bool checked: false

    signal toggled()

    implicitWidth: 52
    implicitHeight: 30
    radius: height / 2
    opacity: enabled ? 1 : 0.4

    color: checked ? "#80bfff" : "#404040"

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Rectangle {
        width: toggle.height - 6
        height: width
        radius: width / 2
        y: 3
        x: toggle.checked ? toggle.width - width - 3 : 3
        color: "white"

        Behavior on x {
            NumberAnimation { duration: 120 }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: toggle.toggled()
    }
}
