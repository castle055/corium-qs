import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import "../../services"

Item {
    id: root

    required property string directory
    required property string name
    required property var metadata

    property string color: (metadata != null && metadata.color != null && metadata.color.length > 0) ? metadata.color : "#001115"
    property string template: (metadata != null && metadata.template != null && metadata.template.length > 0) ? metadata.template : "default"

    property int thumbnailWidth: 92
    property int thumbnailHeight: 129
    property int spacing: 8
    property int padding: 18

    implicitHeight: previewBlock.height + 2 * padding

    FolderListModel {
        id: files

        folder: "file://" + root.directory
        showDirs: false
        showFiles: true
        nameFilters: ["*.xopp", "*.XOPP", "*.pdf", "*.PDF"]
        sortField: FolderListModel.Name
        sortReversed: false
    }

    Rectangle {
        anchors.fill: parent
        color: root.color
        radius: 8
    }

    ColumnLayout {
        id: previewBlock
        spacing: 16
        width: root.width - 2*root.padding
        anchors.centerIn: parent


        Text {
            color: "white"
            text: "  " + ((root.metadata != null && root.metadata.name != null && metadata.name.length > 0) ? metadata.name : root.name)
            font.pointSize: 14
        }

        ScrollView {
            Layout.fillWidth: true

            RowLayout {
                id: previews

                spacing: root.spacing

                Repeater {
                    model: files

                    delegate: NotebookVolumeCard {
                        required property string filePath
                        required property date fileModified

                        file_path: filePath
                        file_modified: fileModified

                        width: root.thumbnailWidth
                        height: root.thumbnailHeight
                    }
                }

                Rectangle {
                    id: newNotebookCard
                    width: root.thumbnailWidth
                    height: root.thumbnailHeight
                    color: mouseArea.containsMouse? "#222222": "#111111"
                    border.color: "#555555"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: "#999999"
                        font.pointSize: 34
                        font.bold: true
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            let nextIndex = 0
                            for (let i = 0; i < files.count; i++) {
                                // Only files named with a two-digit prefix ("03_...") count.
                                const prefix = files.get(i, "fileBaseName").substring(0, 2)
                                if (/^\d\d$/.test(prefix))
                                    nextIndex = Math.max(nextIndex, parseInt(prefix, 10) + 1)
                            }
                            const newName = ("00" + nextIndex).slice(-2) + "_Untitled.xopp"
                            //console.log("Next name: " + newName)

                            Xournalpp.createNewVolume(root.directory, newName, root.template)
                        }
                    }
                }
            }

            onContentWidthChanged: {
                contentItem.contentX = contentItem.contentWidth - width //+ 20
            }
            onWidthChanged: {
                contentItem.contentX = contentItem.contentWidth - width //+ 20
            }
            Component.onCompleted: {
                //contentItem.rightMargin = 20
            }
        }
    }
}
