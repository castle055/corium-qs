pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    FileView {
        id: stateFile

        path: Quickshell.statePath("launcher.json")

        adapter: JsonAdapter {
            property list<string> favorites: []
            property list<string> recents: []
        }

        onAdapterUpdated: writeAdapter()

        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                console.log("Launcher state file does not exist; creating it.")
                writeAdapter()
            } else {
                console.warn("Could not load launcher state:", error)
            }
        }

        onSaveFailed: function(error) {
            console.warn("Could not save launcher state:", error)
        }
    }

    readonly property list<string> favorites:
        stateFile.adapter.favorites

    readonly property list<string> recents:
        stateFile.adapter.recents

    function isFavorite(app) {
        return favorites.includes(app.id)
    }

    function toggleFavorite(app) {
        let updatedFavorites

        if (favorites.includes(app.id)) {
            updatedFavorites = favorites.filter(id => id !== app.id)
        } else {
            updatedFavorites = [...favorites, app.id]
        }

        stateFile.adapter.favorites = updatedFavorites
    }

    function launchApplication(app) {
        const updatedRecents = [
            app.id,
            ...recents.filter(id => id !== app.id)
        ].slice(0, 12)

        stateFile.adapter.recents = updatedRecents

        app.execute()
    }
}
