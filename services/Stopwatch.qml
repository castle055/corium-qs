pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A stopwatch with laps.
 *
 * It stores when it was started rather than counting ticks, so it stays exact
 * and keeps running through config reloads and Quickshell restarts. Nothing
 * ticks here: whoever shows the time calls elapsed() as often as it wants.
 */
Singleton {
    id: root

    property bool running: false
    // Date.now() when last started, and time counted before that.
    property real startedAt: 0
    property real accumulated: 0
    // Total time at each lap press, in milliseconds, oldest first.
    property var laps: []

    readonly property bool started: running || accumulated > 0

    // Milliseconds on the clock at `now` (from Date.now()).
    function elapsed(now) {
        return root.accumulated + (root.running ? Math.max(0, now - root.startedAt) : 0)
    }

    function start() {
        if (root.running)
            return
        root.startedAt = Date.now()
        root.running = true
        save()
    }

    function pause() {
        if (!root.running)
            return
        root.accumulated = elapsed(Date.now())
        root.running = false
        save()
    }

    function lap() {
        if (!root.running)
            return
        root.laps = [...root.laps, elapsed(Date.now())]
        save()
    }

    function reset() {
        root.running = false
        root.startedAt = 0
        root.accumulated = 0
        root.laps = []
        save()
    }

    // "01:23.45", "1:02:03.45"
    function format(ms) {
        const cs = Math.floor(ms / 10)
        const pad = n => String(n).padStart(2, "0")
        const h = Math.floor(cs / 360000)
        const m = Math.floor(cs / 6000) % 60
        const s = Math.floor(cs / 100) % 60
        return (h > 0 ? h + ":" : "") + pad(m) + ":" + pad(s) + "." + pad(cs % 100)
    }

    // Saved as plain JSON text: JsonAdapter doesn't reliably keep several
    // properties written in a row, nor load an object held in a var.
    function save() {
        stateFile.setText(JSON.stringify({
            running: root.running,
            startedAt: root.startedAt,
            accumulated: root.accumulated,
            laps: root.laps,
        }, null, 2))
    }

    // Read once, synchronously, before anything can use (and overwrite) the state.
    Component.onCompleted: {
        const text = stateFile.text()
        if (!text)
            return
        try {
            const saved = JSON.parse(text)
            root.running = saved.running === true
            root.startedAt = Number(saved.startedAt) || 0
            root.accumulated = Number(saved.accumulated) || 0
            root.laps = Array.isArray(saved.laps) ? saved.laps : []
        } catch (e) {
            console.warn("Could not read stopwatch state:", e)
        }
    }

    FileView {
        id: stateFile

        path: Quickshell.statePath("stopwatch.json")
        printErrors: false
        blockLoading: true

        onLoadFailed: function(error) {
            if (error !== FileViewError.FileNotFound)
                console.warn("Could not load stopwatch:", error)
        }

        onSaveFailed: function(error) {
            console.warn("Could not save stopwatch:", error)
        }
    }
}
