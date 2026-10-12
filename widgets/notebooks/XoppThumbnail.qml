import Quickshell
import QtQuick
import "../../services"

Item {
    id: root

    required property string xoppPath
    required property date mTime

    Image {
        id: image

        anchors.fill: parent

        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false

        visible: status === Image.Ready
    }

    Component.onCompleted: Xournalpp.generateThumbnail(root.xoppPath, root.mTime, (thumbnailPath) => {
        image.source = ""
        image.source = "file://" + thumbnailPath
    })

    onMTimeChanged: Xournalpp.generateThumbnail(root.xoppPath, root.mTime, (thumbnailPath) => {
        image.source = ""
        image.source = "file://" + thumbnailPath
    })
}
