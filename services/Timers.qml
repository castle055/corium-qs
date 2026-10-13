pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Countdown timers. Several can run at once; each one sends a notification
 * when it finishes and, if asked to, plays a sound.
 *
 * Timers are saved with their end time, so they keep counting through config
 * reloads and Quickshell restarts. One that ended while Quickshell wasn't
 * running is reported as soon as it starts again.
 */
Singleton {
    id: root

    // Played when a timer that has sound enabled finishes.
    property string soundFile: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

    // Updated several times a second while a timer is counting down.
    property real now: Date.now()

    // Each timer: { id, label, duration, endsAt, remaining, paused, sound },
    // with times in milliseconds. A running timer's state is its endsAt; a
    // paused one's is its remaining time.
    readonly property var timers: stateFile.adapter.timers

    readonly property bool active: timers.length > 0
    readonly property bool counting: timers.some(t => !t.paused)
    // True when a running timer is close to finishing; the bar shows a soft warning.
    readonly property bool almostDone: timers.some(t => !t.paused && remaining(t) <= warnThreshold(t))

    function remaining(timer) {
        return timer.paused ? timer.remaining : Math.max(0, timer.endsAt - root.now)
    }

    function progress(timer) {
        return timer.duration > 0 ? 1 - remaining(timer) / timer.duration : 1
    }

    // The last fifth of the timer, between 5 seconds and a minute.
    function warnThreshold(timer) {
        return Math.min(60000, Math.max(5000, timer.duration * 0.2))
    }

    // "4:05", "1:02:03"
    function format(ms) {
        const total = Math.ceil(ms / 1000)
        const h = Math.floor(total / 3600)
        const m = Math.floor(total / 60) % 60
        const s = total % 60
        const pad = n => String(n).padStart(2, "0")
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s)
    }

    // "1 h 30 min", "5 min", "45 s"
    function describe(ms) {
        const total = Math.round(ms / 1000)
        const parts = []
        if (total >= 3600)
            parts.push(Math.floor(total / 3600) + " h")
        if (total % 3600 >= 60)
            parts.push(Math.floor(total / 60) % 60 + " min")
        if (total % 60 > 0)
            parts.push(total % 60 + " s")
        return parts.join(" ")
    }

    function start(duration, label, sound) {
        if (duration <= 0)
            return
        root.now = Date.now()
        save([...timers, {
            id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            label: label,
            duration: duration,
            endsAt: root.now + duration,
            remaining: duration,
            paused: false,
            sound: sound,
        }])
    }

    function pause(id) {
        root.now = Date.now()
        update(id, t => t.paused ? t : Object.assign({}, t, { paused: true, remaining: remaining(t) }))
    }

    function resume(id) {
        root.now = Date.now()
        update(id, t => t.paused ? Object.assign({}, t, { paused: false, endsAt: root.now + t.remaining }) : t)
    }

    // Adds time to a timer; the total grows too, so its progress bar stays honest.
    function addTime(id, ms) {
        update(id, t => Object.assign({}, t, {
            duration: t.duration + ms,
            endsAt: t.endsAt + ms,
            remaining: t.remaining + ms,
        }))
    }

    function cancel(id) {
        save(timers.filter(t => t.id !== id))
    }

    function update(id, change) {
        save(timers.map(t => t.id === id ? change(t) : t))
    }

    function save(list) {
        stateFile.adapter.timers = list
    }

    function finishDue() {
        root.now = Date.now()
        const due = timers.filter(t => !t.paused && t.endsAt <= root.now)
        if (due.length === 0)
            return

        save(timers.filter(t => !due.includes(t)))
        for (const timer of due)
            notify(timer)
    }

    function notify(timer) {
        // Ended long ago: it finished while Quickshell wasn't running.
        const late = root.now - timer.endsAt > 5000
        const body = late
                ? describe(timer.duration) + " timer finished at "
                  + new Date(timer.endsAt).toLocaleTimeString(Qt.locale(), "HH:mm")
                : describe(timer.duration) + " timer is up"

        Quickshell.execDetached([
            "notify-send",
            "--app-name=Clock",
            "--icon=alarm-symbolic",
            "--urgency=critical",
            timer.label || "Timer finished",
            body
        ])

        if (timer.sound && !late)
            Quickshell.execDetached(["pw-play", root.soundFile])
    }

    Timer {
        interval: 250
        repeat: true
        running: root.counting
        triggeredOnStart: true
        onTriggered: root.finishDue()
    }

    FileView {
        id: stateFile

        path: Quickshell.statePath("timers.json")

        adapter: JsonAdapter {
            property var timers: []
        }

        onAdapterUpdated: writeAdapter()

        onLoaded: root.finishDue()

        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
            else
                console.warn("Could not load timers:", error)
        }

        onSaveFailed: function(error) {
            console.warn("Could not save timers:", error)
        }
    }
}
