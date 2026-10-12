import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel

Item {
    id: root

    required property string directory

    property int thumbnailWidth: 92
    property int thumbnailHeight: 48

    signal changeDir(dir: string)

    //implicitWidth: content.width
    implicitHeight: content.height

    NotebookDirectoryModel {
        id: entries
        directory: root.directory
    }

    Column {
        id: content
        spacing: 30

        Text {
            color: "#333333"
            text: "Directory Empty"
            font.pointSize: 18
            font.bold: false
            visible: entries.notebooks.values.length == 0 && entries.directories.values.length == 0
        }

        Column {
            spacing: 10
          //Text {
          //    color: "white"
          //    text: "Directories"
          //    font.pointSize: 18
          //    font.bold: true
          //    visible: entries.directories.values.length > 0
          //}
            GridLayout {
                id: directories

                width: root.width
                columns: 2

                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: entries.directories

                    delegate: DirectoryPreview {
                        required property var modelData
                        directory: modelData.path
                        name: modelData.name
                        Layout.fillWidth: true
                        onClicked: root.changeDir(modelData.path)
                    }
                }
            }
        }

        Column {
            spacing: 10
          //Text {
          //    color: "white"
          //    text: "Notebooks"
          //    font.pointSize: 18
          //    font.bold: true
          //    visible: entries.notebooks.values.length > 0
          //}
            ColumnLayout {
                id: previews

                width: root.width
                spacing: 10

                Repeater {
                    model: entries.notebooks

                    delegate: NotebookPreview {
                        required property var modelData
                        directory: modelData.path
                        name: modelData.name
                        metadata: modelData.metadata
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
