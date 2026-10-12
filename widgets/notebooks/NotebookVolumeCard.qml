import Quickshell
import Quickshell.Io
import QtQuick
import "../../services"


Item {
    id: root

    required property string file_path
    required property date file_modified

    property var page_count: 0

    //Rectangle {
    // anchors.fill: parent
    // color: "green"
    //}

    XoppThumbnail {
        xoppPath: root.file_path
        mTime: root.file_modified
        width: root.width
        height: root.height
    }

    Rectangle {
        color: "#99000000"
        radius: 4

        width: pageCountBadge.width + 10
        height: 20

        x: parent.width - width - 6
        y: parent.height - height - 6

        Text {
            id: pageCountBadge
            anchors.centerIn: parent
            text: root.page_count + " 󱀲"
            color: "white"
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Xournalpp.open(root.file_path)
    }

    Component.onCompleted: Xournalpp.getPageCount(root.file_path, (count) => {
        root.page_count = count > 0? count: 0
    })
}
