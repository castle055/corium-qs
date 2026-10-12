import Quickshell.Io
import QtQuick

QtObject {
    id: root

    required property string directory

    readonly property bool ready: marker.loaded || marker.loadFailed
    readonly property bool isNotebook: marker.loaded
    property var metadata: marker.loaded
        ? JSON.parse(marker.text())
        : null

    property FileView marker: FileView {
        path: root.directory + "/notebook.json"
        preload: true
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            try {
                reload()
                root.metadata = JSON.parse(text())
            } catch(e) {
                console.log(e)
            }
        }
    }
}
