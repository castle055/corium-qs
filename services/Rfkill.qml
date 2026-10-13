pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

/**
 * Radio kill switches (rfkill): which radios are blocked, and airplane mode.
 *
 * State is read with `rfkill -J` and refreshed whenever `rfkill event`
 * reports a change. Blocking and unblocking need write access to
 * /dev/rfkill, which logind gives the active session.
 *
 * Airplane mode isn't a setting of its own: it is on when every Wi-Fi and
 * Bluetooth radio is blocked. Turning one radio back on therefore ends it,
 * as on a phone.
 *
 * iwd and BlueZ power a radio up as soon as it's unblocked, so turning
 * airplane mode off would switch everything on. Instead, which radios were on
 * is remembered (in airplane.json) when it's turned on, and only those are
 * unblocked; the others stay blocked, which shows as off.
 */
Singleton {
    id: root

    // Radios that were on when airplane mode was turned on from here:
    // { wlan: bool, bluetooth: bool }, or null if unknown (e.g. it was
    // turned on with a hardware key).
    property var radiosBeforeAirplane: null

    // [{ id, type, device, soft, hard }]; type is wlan, bluetooth, wwan, ...
    property var devices: []

    readonly property var radios: devices.filter(d => d.type === "wlan" || d.type === "bluetooth")
    readonly property bool available: radios.length > 0
    readonly property bool airplaneMode: available && radios.every(d => d.soft || d.hard)
    // A hardware switch is off; software can't turn these radios on.
    readonly property bool hardBlocked: radios.some(d => d.hard)

    function blocked(type) {
        const matching = devices.filter(d => d.type === type)
        return matching.length > 0 && matching.every(d => d.soft || d.hard)
    }

    // callback(ok, message)
    function setAirplaneMode(on, callback) {
        if (on) {
            radiosBeforeAirplane = {
                wlan: Iwd.powered,
                bluetooth: Bluetooth.defaultAdapter?.enabled ?? false
            }
            save()
            run(["rfkill", "block", "all"], callback)
            return
        }

        const before = radiosBeforeAirplane
        if (!before) {
            run(["rfkill", "unblock", "all"], callback)
        } else if (before.wlan && before.bluetooth) {
            run(["rfkill", "unblock", "wlan", "bluetooth"], callback)
        } else if (before.bluetooth) {
            run(["rfkill", "unblock", "bluetooth"], callback)
        } else {
            // Wi-Fi alone was on, or nothing was: leaving airplane mode should
            // still get you connected.
            run(["rfkill", "unblock", "wlan"], callback)
        }
    }

    // Forget the radios once airplane mode ends, however it ends (turning
    // Wi-Fi or Bluetooth on from its tile ends it too).
    onAirplaneModeChanged: {
        if (!airplaneMode && radiosBeforeAirplane) {
            radiosBeforeAirplane = null
            save()
        }
    }

    function save() {
        stateFile.setText(JSON.stringify({ radiosBeforeAirplane: radiosBeforeAirplane }, null, 2))
    }

    // Read once, synchronously, before anything can use (and overwrite) the state.
    Component.onCompleted: {
        const text = stateFile.text()
        if (!text)
            return
        try {
            const saved = JSON.parse(text).radiosBeforeAirplane
            if (saved)
                radiosBeforeAirplane = { wlan: saved.wlan === true, bluetooth: saved.bluetooth === true }
        } catch (e) {
            console.warn("Could not read airplane mode state:", e)
        }
    }

    FileView {
        id: stateFile

        path: Quickshell.statePath("airplane.json")
        printErrors: false
        blockLoading: true

        onLoadFailed: function(error) {
            if (error !== FileViewError.FileNotFound)
                console.warn("Could not load airplane mode state:", error)
        }

        onSaveFailed: function(error) {
            console.warn("Could not save airplane mode state:", error)
        }
    }

    function unblock(type, callback) {
        run(["rfkill", "unblock", type], callback)
    }

    function run(command, callback) {
        const operation = commandComponent.createObject(root, { command: command, callback: callback })
        operation.running = true
    }

    function apply(text) {
        if (text.trim() === "") {
            // rfkill prints nothing at all when there are no devices.
            devices = []
            return
        }
        try {
            devices = JSON.parse(text).rfkilldevices.map(d => ({
                id: d.id,
                type: d.type,
                device: d.device,
                soft: d.soft === "blocked",
                hard: d.hard === "blocked"
            }))
        } catch (e) {
            console.warn("Rfkill: could not parse rfkill -J:", e)
        }
    }

    Component {
        id: commandComponent

        Process {
            id: operation

            property var callback

            stderr: StdioCollector {
                id: stderrCollector
            }

            onExited: function(exitCode, exitStatus) {
                if (exitCode === 0)
                    operation.callback?.(true, "")
                else
                    operation.callback?.(false, stderrCollector.text.trim() || "rfkill failed.")
                refreshDebounce.restart()
                operation.destroy()
            }
        }
    }

    Process {
        id: reader

        command: ["rfkill", "-J"]

        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
    }

    // Prints the current state on start, then a line per change.
    Process {
        id: monitor

        command: ["rfkill", "event"]
        running: true

        stdout: SplitParser {
            onRead: refreshDebounce.restart()
        }

        onExited: monitorRestart.start()
    }

    Timer {
        id: monitorRestart

        interval: 3000

        onTriggered: monitor.running = true
    }

    Timer {
        id: refreshDebounce

        interval: 100

        onTriggered: {
            if (reader.running)
                restart()
            else
                reader.running = true
        }
    }
}
