import Quickshell
import QtQuick
import Qt.labs.folderlistmodel

Item {
    id: root

    required property string directory

    /*
     * The model exposed to the view.
     *
     * Each entry has:
     *
     *   path       - directory path
     *   name       - directory name
     *   ready      - classification has completed
     *   isNotebook - directory contains notebook.json
     */
    readonly property alias directories: directoriesModel
    readonly property alias notebooks: notebooksModel

    /*
     * Incremented whenever the set of classified directories changes
     * or one of their classifications becomes ready.
     *
     * ScriptModel.values depends on this property, so changing it
     * causes the values expression to be reevaluated.
     */
    property int generation: 0

    function rebuild() {
        generation++;
    }

    /*
     * Discover child directories.
     */
    FolderListModel {
        id: folders

        folder: "file://" + root.directory

        showDirs: true
        showFiles: false

        sortField: FolderListModel.Name
        sortReversed: false
    }

    /*
     * Create one classifier for every directory.
     */
    Instantiator {
        id: classifiers

        model: folders

        delegate: Item {
            id: classifier
            required property string filePath

            readonly property string path: filePath
            readonly property string name:
                path.substring(path.lastIndexOf("/") + 1)

            readonly property bool ready: marker.ready
            readonly property bool isNotebook: marker.isNotebook
            readonly property var metadata: marker.metadata

            NotebookMarker {
                id: marker
                directory: filePath
                onReadyChanged: root.rebuild()
            }
        }

        onObjectAdded: root.rebuild()
        onObjectRemoved: root.rebuild()
    }

    ScriptModel {
        id: directoriesModel

        values: {
            root.generation;

            const result = [];

            for (let i = 0; i < classifiers.count; ++i) {
                const entry = classifiers.objectAt(i);

                if (entry && entry.ready && !entry.isNotebook) {
                    result.push(entry)
                }
            }

            return result.sort((a, b) => {
                return a.name.localeCompare(b.name);
            });
        }

        objectProp: "path"
    }

    ScriptModel {
        id: notebooksModel

        values: {
            root.generation;

            const result = [];

            for (let i = 0; i < classifiers.count; ++i) {
                const entry = classifiers.objectAt(i);

                if (entry && entry.ready && entry.isNotebook) {
                    result.push(entry)
                }
            }

            //console.log(JSON.stringify(result))
            return result.sort((a, b) => {
                return a.name.localeCompare(b.name);
            });
        }

        objectProp: "path"
    }
}
