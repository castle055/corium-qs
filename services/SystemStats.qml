pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * CPU, memory and swap usage, sampled from /proc every couple of seconds,
 * with a rolling history for graphs.
 *
 * Percentages are 0–100. Memory "used" is total minus available, as `free`
 * reports it, so caches the kernel can drop don't count.
 */
Singleton {
    id: root

    readonly property int interval: 2000
    // Ten minutes of samples.
    readonly property int historyLength: 300

    property real cpu: 0
    property real memory: 0
    property real swap: 0

    // In bytes.
    property real memoryTotal: 0
    property real memoryUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0

    property int cores: 1

    // Oldest first; at most historyLength entries.
    property var cpuHistory: []
    property var memoryHistory: []
    property var swapHistory: []

    property var previous: null

    // "1.2 GiB", "340 MiB"
    function formatBytes(bytes) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let value = bytes
        let unit = 0
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024
            unit++
        }
        return (unit >= 3 ? value.toFixed(1) : Math.round(value)) + " " + units[unit]
    }

    function push(history, value) {
        const next = history.length >= root.historyLength ? history.slice(1) : history.slice()
        next.push(value)
        return next
    }

    function parse(text) {
        const values = {}
        let cores = 0

        for (const line of text.split("\n")) {
            if (line.startsWith("cpu ")) {
                // user nice system idle iowait irq softirq steal
                const f = line.trim().split(/\s+/).slice(1, 9).map(Number)
                const idle = f[3] + f[4]
                const total = f.reduce((a, b) => a + b, 0)
                if (root.previous && total > root.previous.total)
                    root.cpu = 100 * (1 - (idle - root.previous.idle) / (total - root.previous.total))
                root.previous = { idle: idle, total: total }
            } else if (/^cpu\d/.test(line)) {
                cores++
            } else {
                const match = /^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)/.exec(line)
                if (match)
                    values[match[1]] = Number(match[2]) * 1024
            }
        }

        root.cores = Math.max(1, cores)
        root.memoryTotal = values.MemTotal ?? 0
        root.memoryUsed = root.memoryTotal - (values.MemAvailable ?? 0)
        root.swapTotal = values.SwapTotal ?? 0
        root.swapUsed = root.swapTotal - (values.SwapFree ?? 0)
        root.memory = root.memoryTotal > 0 ? 100 * root.memoryUsed / root.memoryTotal : 0
        root.swap = root.swapTotal > 0 ? 100 * root.swapUsed / root.swapTotal : 0

        root.cpuHistory = push(root.cpuHistory, root.cpu)
        root.memoryHistory = push(root.memoryHistory, root.memory)
        root.swapHistory = push(root.swapHistory, root.swap)
    }

    Process {
        id: reader

        command: ["cat", "/proc/stat", "/proc/meminfo"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }
}
