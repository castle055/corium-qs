pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../services"
import "../utils"

// Running processes, sortable, with actions to end or kill them.
Item {
    id: page

    // Refresh only while the page can be seen.
    property bool active: true

    property string sortKey: "cpu"
    property bool sortDescending: true
    property string filter: ""

    // The process whose actions are showing. While set, the list is frozen
    // so rows don't move under a finger about to tap "Kill".
    property int expandedPid: -1
    readonly property bool frozen: expandedPid !== -1

    property string message: ""
    property bool messageIsError: false

    // Previous CPU time per pid (in clock ticks) and when it was read.
    property var previousTicks: ({})
    property real previousTime: 0
    property var lastSample: []

    readonly property int clockTicks: 100
    readonly property int pageSize: 4096

    readonly property var sortOptions: [
        { key: "cpu", label: "CPU", descending: true },
        { key: "memory", label: "Memory", descending: true },
        { key: "name", label: "Name", descending: false },
        { key: "pid", label: "PID", descending: false },
    ]

    function setSort(key, defaultDescending) {
        if (page.sortKey === key) {
            page.sortDescending = !page.sortDescending
        } else {
            page.sortKey = key
            page.sortDescending = defaultDescending
        }
        page.show(page.lastSample)
    }

    function parse(text) {
        const [psPart, statPart] = text.split("\n===\n")

        const users = {}
        for (const line of (psPart ?? "").split("\n")) {
            const match = /^\s*(\d+)\s+(\S+)/.exec(line)
            if (match)
                users[match[1]] = match[2]
        }

        const now = Date.now()
        const seconds = (now - page.previousTime) / 1000
        const ticks = {}
        const processes = []

        for (const line of (statPart ?? "").split("\n")) {
            const open = line.indexOf("(")
            const close = line.lastIndexOf(")")
            if (open < 0 || close < 0)
                continue

            const pid = Number(line.slice(0, open))
            const fields = line.slice(close + 2).split(" ")
            const ppid = Number(fields[1])
            // Hide kernel threads.
            if (pid === 2 || ppid === 2)
                continue

            const cpuTicks = Number(fields[11]) + Number(fields[12])
            ticks[pid] = cpuTicks

            const before = page.previousTicks[pid]
            const cpu = before !== undefined && seconds > 0
                    ? 100 * (cpuTicks - before) / page.clockTicks / seconds / SystemStats.cores
                    : 0

            processes.push({
                pid: pid,
                name: line.slice(open + 1, close),
                user: users[pid] ?? "",
                state: fields[0],
                cpu: Math.max(0, cpu),
                memory: Number(fields[21]) * page.pageSize,
            })
        }

        page.previousTicks = ticks
        page.previousTime = now
        page.lastSample = processes
        page.show(processes)
    }

    // Sorts, filters and copies into the model in place, so the list keeps
    // its scroll position.
    function show(processes) {
        const needle = page.filter.trim().toLowerCase()
        const rows = processes.filter(p => !needle
                                      || p.name.toLowerCase().includes(needle)
                                      || String(p.pid) === needle
                                      || p.user.toLowerCase() === needle)

        const key = page.sortKey
        const direction = page.sortDescending ? -1 : 1
        rows.sort((a, b) => {
            const x = a[key], y = b[key]
            const order = typeof x === "string" ? x.localeCompare(y) : x - y
            return order !== 0 ? direction * order : a.pid - b.pid
        })

        for (let i = 0; i < rows.length; i++) {
            if (i < processModel.count)
                processModel.set(i, rows[i])
            else
                processModel.append(rows[i])
        }
        if (processModel.count > rows.length)
            processModel.remove(rows.length, processModel.count - rows.length)
    }

    function refresh() {
        if (!reader.running)
            reader.running = true
    }

    function sendSignal(pid, name, signalName) {
        killer.pid = pid
        killer.name = name
        killer.signalName = signalName
        killer.command = ["kill", "-s", signalName, "--", String(pid)]
        killer.running = true
    }

    function showMessage(text, isError) {
        page.message = text
        page.messageIsError = isError
        messageTimer.restart()
    }

    // CPU use needs two samples, so take a quick second one when opened.
    function start() {
        refresh()
        secondSample.restart()
    }

    onActiveChanged: {
        if (active)
            start()
        else
            expandedPid = -1
    }
    Component.onCompleted: if (active) start()
    onFilterChanged: show(lastSample)

    ListModel {
        id: processModel
    }

    Process {
        id: reader

        command: ["sh", "-c", "ps -eo pid=,user:32=; echo ===; cat /proc/[0-9]*/stat 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: page.parse(text)
        }
    }

    Timer {
        id: secondSample
        interval: 500
        onTriggered: page.refresh()
    }

    Timer {
        interval: SystemStats.interval
        repeat: true
        running: page.active && !page.frozen
        onTriggered: {
            if (!processList.moving)
                page.refresh()
        }
    }

    Process {
        id: killer

        property int pid
        property string name
        property string signalName

        stderr: StdioCollector {
            id: killErrors
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                page.showMessage((killer.signalName === "KILL" ? "Killed " : "Asked to end ")
                                 + killer.name + " (" + killer.pid + ")", false)
                page.expandedPid = -1
            } else {
                page.showMessage(killErrors.text.trim().replace(/^.*kill:\s*/, "")
                                 || "Could not signal " + killer.name, true)
            }
            page.refresh()
        }
    }

    Timer {
        id: messageTimer
        interval: 5000
        onTriggered: page.message = ""
    }

    Column {
        id: controls

        width: parent.width
        spacing: 10

        // Sort buttons: tap again to reverse.
        Row {
            id: sortRow

            width: parent.width
            spacing: 6

            Repeater {
                model: page.sortOptions

                delegate: Chip {
                    id: sortButton

                    required property var modelData
                    readonly property bool current: page.sortKey === modelData.key

                    width: (sortRow.width - 3 * sortRow.spacing) / 4
                    text: modelData.label + (current ? (page.sortDescending ? "  ↓" : "  ↑") : "")
                    selected: current
                    onClicked: page.setSort(modelData.key, modelData.descending)
                }
            }
        }

        InputField {
            width: parent.width
            placeholderText: "Filter by name, PID or user"
            onTextChanged: page.filter = text
        }

        Item {
            width: parent.width
            height: 18

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.message !== ""
                      ? page.message
                      : processModel.count + " processes"
                        + (page.frozen ? " · paused while a process is open" : "")
                color: page.message !== "" && page.messageIsError ? "#ff7777" : "#aaaaaa"
                font.pixelSize: 12
                elide: Text.ElideRight
                width: parent.width - columnHeaders.width
            }

            Row {
                id: columnHeaders

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: 64
                    horizontalAlignment: Text.AlignRight
                    text: "CPU"
                    color: "#777777"
                    font.pixelSize: 11
                }

                Text {
                    width: 84
                    horizontalAlignment: Text.AlignRight
                    text: "Memory"
                    color: "#777777"
                    font.pixelSize: 11
                }
            }
        }
    }

    ListView {
        id: processList

        anchors.top: controls.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        width: parent.width

        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: processModel

        ScrollBar.vertical: ScrollBar {
            width: 6
        }

        delegate: Rectangle {
            id: row

            required property int pid
            required property string name
            required property string user
            required property string state
            required property real cpu
            required property real memory

            readonly property bool expanded: page.expandedPid === pid

            width: processList.width
            height: expanded ? 52 + details.height + 12 : 52
            radius: 10
            color: expanded ? "#262626" : rowMouse.pressed ? "#262626" : "#1c1c1c"

            MouseArea {
                id: rowMouse

                width: parent.width
                height: 52
                onClicked: {
                    page.expandedPid = row.expanded ? -1 : row.pid
                    if (page.expandedPid !== -1) {
                        cmdline.text = ""
                        cmdlineReader.command = ["sh", "-c", "tr '\\0' ' ' < /proc/" + row.pid + "/cmdline"]
                        cmdlineReader.running = true
                    }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: numbers.left
                anchors.rightMargin: 8
                y: (52 - height) / 2
                spacing: 1

                Text {
                    width: parent.width
                    text: row.name
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: row.pid + (row.user ? " · " + row.user : "")
                    color: "#888888"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Row {
                id: numbers

                anchors.right: parent.right
                anchors.rightMargin: 12
                y: (52 - height) / 2

                Text {
                    width: 64
                    horizontalAlignment: Text.AlignRight
                    text: row.cpu.toFixed(1) + "%"
                    color: row.cpu >= 50 ? "#ffaa00" : row.cpu >= 1 ? "white" : "#777777"
                    font.pixelSize: 13
                    font.features: { "tnum": 1 }
                }

                Text {
                    width: 84
                    horizontalAlignment: Text.AlignRight
                    text: SystemStats.formatBytes(row.memory)
                    color: "white"
                    font.pixelSize: 13
                    font.features: { "tnum": 1 }
                }
            }

            Column {
                id: details

                visible: row.expanded
                x: 14
                y: 52
                width: parent.width - 28
                spacing: 10

                Text {
                    id: cmdline

                    width: parent.width
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    font.family: "monospace"
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                Row {
                    width: parent.width
                    spacing: 8

                    ActionButton {
                        width: (parent.width - 8) / 2
                        text: "End (SIGTERM)"
                        onClicked: page.sendSignal(row.pid, row.name, "TERM")
                    }

                    ActionButton {
                        width: (parent.width - 8) / 2
                        text: "Kill (SIGKILL)"
                        danger: true
                        onClicked: page.sendSignal(row.pid, row.name, "KILL")
                    }
                }
            }

            Process {
                id: cmdlineReader

                stdout: StdioCollector {
                    onStreamFinished: cmdline.text = text.trim() || "[" + row.name + "]"
                }
            }
        }
    }
}
