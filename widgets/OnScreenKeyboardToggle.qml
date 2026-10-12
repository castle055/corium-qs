import Quickshell
import QtQuick

Item {
    id: root

    property bool keyboardVisible: false

    implicitWidth: 48
    implicitHeight: 48

    function toggleKeyboard() {
        Quickshell.execDetached([
            "pkill",
            "-RTMIN",
            "wvkbd-deskintl"
        ])

        keyboardVisible = !keyboardVisible
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2

        color: mouseArea.containsPress ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

        Text {
            anchors.centerIn: parent

            text: "󰌌"
            font.pixelSize: 18

            //opacity: root.keyboardVisible ? 1.0 : 0.55
            color: "white"
            opacity: mouseArea.containsPress? 1: 0.50

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.toggleKeyboard()
        }
    }
}
