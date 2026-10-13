import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    implicitHeight: 48

    property bool popupVisible: false
    //default property alias content: popupWindow.data
    property alias popup: popupWindow.content
    property alias leftSide: popupWindow.leftSide
    property alias fullHeight: popupWindow.fullHeight
    property alias keyboardFocus: popupWindow.keyboardFocus

    Rectangle {
        width: parent.width
        height: 48
        anchors.verticalCenter: parent.verticalCenter
        //radius: 20
        color: root.popupVisible? "#222222": "transparent"
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true

        onEntered: {
        }

        onExited: {
        }

        onClicked: {
            root.popupVisible = true
        }

        property var wheel_acc: 0
    }

    OrganicPopUp {
        id: popupWindow
        visible: root.popupVisible
        onDismissed: root.popupVisible = false
    }
}
