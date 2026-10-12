import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel

Item {
    id: root

    required property string directory
    required property string name

    property int spacing: 8

    signal clicked()

    implicitWidth: 100
    implicitHeight: 70

    Rectangle {
        anchors.fill: parent
        color: "#222222"
        radius: 8
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 18

        color: "white"
        text: "   " + root.name
        font.pointSize: 13
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onClicked: root.clicked()
    }

//  implicitWidth: previews.width
//  implicitHeight: previews.height

//  FolderListModel {
//      id: files
//
//      folder: "file://" + root.directory
//      showDirs: false
//      showFiles: true
//      nameFilters: ["*.xopp", "*.XOPP"]
//      sortField: FolderListModel.Name
//      sortReversed: false
//  }
//
//  Row {
//      id: previews
//
//      spacing: root.spacing
//
//      Repeater {
//          model: files
//
//          delegate: XoppThumbnail {
//              required property string filePath
//
//              xoppPath: filePath
//              width: root.thumbnailWidth
//              height: root.thumbnailHeight
//          }
//      }
//  }
}
