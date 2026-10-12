import Quickshell
import QtQuick

Item {
    id: root

    implicitWidth: 48
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: height / 2

        color: mouseArea.containsPress ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

        Text {
            anchors.centerIn: parent

            text: "󰄄"
            font.pixelSize: 18

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

            onClicked: Quickshell.execDetached(["screenshot"])
        }
    }
}
