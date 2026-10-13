import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "utils"
import "notebooks"
import "../services"

BarPopupButton {
    id: root

    implicitWidth: 48
    implicitHeight: 48

    leftSide: true
    fullHeight: true

    property var screen

    Row {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: "white"
            font.pixelSize: 18
            font.bold: false
        }
    }

    popup: NotebookManager {
        basePath: Quickshell.env("HOME") + "/Notes/Notebooks"
        implicitWidth: 450
        implicitHeight: screen.height - 48
    }
}
