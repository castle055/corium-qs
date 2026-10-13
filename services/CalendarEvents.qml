pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Calendar events from KOrganizer (Akonadi), through the corium-calendar
 * helper in helpers/calendar, which has to be built first (see helpers/README.md).
 *
 * fetch(from, to, callback) calls callback(result) with
 *   { events: [...], calendars: { <id>: { name, color } } }
 * or with null if the helper isn't running or the request failed. Each event
 * has uid, summary, location, allDay, start, end, days (YYYY-MM-DD strings)
 * and calendar (an id into calendars).
 *
 * `updated` fires whenever the events may have changed; fetch again then.
 */
Singleton {
    id: root

    readonly property string helperPath: Quickshell.shellDir + "/helpers/build/calendar/corium-calendar"

    // True once the helper has loaded the events and is answering requests.
    property bool ready: false

    signal updated()

    property int nextId: 1
    property var callbacks: ({})

    function isoDate(date) {
        return Qt.formatDate(date, "yyyy-MM-dd")
    }

    function fetch(from, to, callback) {
        if (!helper.running) {
            callback(null)
            return
        }

        const id = root.nextId++
        root.callbacks[id] = callback
        helper.write(JSON.stringify({ id: id, from: isoDate(from), to: isoDate(to) }) + "\n")
    }

    function finish(id, result) {
        const callback = root.callbacks[id]
        if (!callback)
            return
        delete root.callbacks[id]
        callback(result)
    }

    function failAll() {
        const pending = root.callbacks
        root.callbacks = {}
        for (const id in pending)
            pending[id](null)
    }

    function handle(line) {
        let message
        try {
            message = JSON.parse(line)
        } catch (e) {
            console.warn("CalendarEvents: unreadable helper output:", line)
            return
        }

        switch (message.type) {
        case "ready":
            root.ready = true
            root.updated()
            break
        case "changed":
            root.updated()
            break
        case "events": {
            const calendars = {}
            for (const calendar of message.calendars)
                calendars[calendar.id] = calendar
            root.finish(message.id, { events: message.events, calendars: calendars })
            break
        }
        case "error":
            console.warn("CalendarEvents:", message.message)
            if (message.id !== undefined && message.id !== null)
                root.finish(message.id, null)
            break
        }
    }

    Process {
        id: helper

        command: [root.helperPath, "serve"]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.handle(line)
        }

        onRunningChanged: {
            if (running)
                return
            root.ready = false
            root.failAll()
            restartTimer.start()
        }
    }

    // Bring the helper back if it crashes, or once it has been built.
    Timer {
        id: restartTimer
        interval: 30000
        onTriggered: helper.running = true
    }
}
