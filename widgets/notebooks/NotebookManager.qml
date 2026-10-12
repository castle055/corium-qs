import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property string basePath

    property string currentPath: basePath
    property bool canGoBack: currentPath != basePath && currentPath.startsWith(basePath)

    ColumnLayout {
        width: root.width

        RowLayout {
            spacing: 15

            Row {
                spacing: 0

                Rectangle {
                    id: backButton

                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"

                    opacity: root.canGoBack? 1: 0.2

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: "white"
                        font.bold: true
                        font.pointSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.canGoBack) {
                                currentPath = currentPath.substring(0, currentPath.lastIndexOf("/"))
                            }
                        }
                    }
                }
                Rectangle {
                    id: homeButton

                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"

                    opacity: root.canGoBack? 1: 0.2

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: "white"
                        font.bold: true
                        font.pointSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.canGoBack) {
                                currentPath = basePath
                            }
                        }
                    }
                }
            }

            Text {
                color: "white"
                text: currentPath.substring(currentPath.lastIndexOf("/") + 1)
                font.pointSize: 18
                font.bold: true
            }
        }

        NotebookDirView {
            Layout.margins: 10
            Layout.fillWidth: true
            directory: currentPath
            //implicitWidth: test_win.implicitWidth
            onChangeDir: (dir) => {
                currentPath = dir
            }
        }
    }
}
