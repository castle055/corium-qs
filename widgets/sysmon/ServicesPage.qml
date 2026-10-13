pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../utils"

// systemd services. User services can be started, stopped, restarted and
// their logs read; system services are only listed.
Item {
    id: page

    // Refresh only while the page can be seen.
    property bool active: true

    // "user" or "system"
    property string scope: "user"
    // "all", "running" or "failed"
    property string statusFilter: "all"
    property string filter: ""

    property string expandedUnit: ""
    // The unit whose logs are open, or "".
    property string logsUnit: ""

    property string message: ""
    property bool messageIsError: false

    property var services: []

    readonly property bool isUser: scope === "user"

    function statusColor(active) {
        switch (active) {
        case "active": return "#77dd77"
        case "failed": return "#ff7777"
        case "activating":
        case "deactivating":
        case "reloading": return "#ffaa00"
        }
        return "#555555"
    }

    // Sort order: failed, then running (or changing state), then stopped.
    function stateRank(active) {
        switch (active) {
        case "failed": return 0
        case "active":
        case "activating":
        case "deactivating":
        case "reloading": return 1
        }
        return 2
    }

    function refresh() {
        if (lister.running)
            return
        // Read scope directly: isUser may not have updated yet inside onScopeChanged.
        const user = page.scope === "user"
        const flag = user ? "--user" : "--system"
        lister.scopeLoaded = page.scope
        lister.command = ["sh", "-c",
            "systemctl " + flag + " list-units --type=service --all --output=json --no-pager; echo; echo ===; "
            + "systemctl " + flag + " list-unit-files --type=service --output=json --no-pager"
            // Services written by hand: the unit files in ~/.config/systemd/user.
            + (user ? "; echo; echo ===; find \"$HOME/.config/systemd/user\" -maxdepth 1 -name '*.service' -printf '%f\\n'" : "")]
        lister.running = true
    }

    function parse(text, scope) {
        if (scope !== page.scope)
            return

        const [unitsText, filesText, ownText] = text.split("\n===\n")
        const own = new Set((ownText ?? "").split("\n").filter(name => name !== ""))
        let units = [], files = []
        try {
            units = JSON.parse(unitsText)
            files = JSON.parse(filesText)
        } catch (e) {
            console.warn("ServicesPage: could not read systemctl output:", e)
            return
        }

        const byName = {}
        for (const file of files) {
            // Templates can't run without an instance; aliases duplicate another unit.
            if (file.unit_file.includes("@.") || file.state === "alias")
                continue
            byName[file.unit_file] = {
                unit: file.unit_file, description: "", active: "inactive", sub: "dead", enabled: file.state, group: "other",
            }
        }
        for (const unit of units) {
            if (unit.load === "not-found" && !byName[unit.unit])
                continue
            byName[unit.unit] = Object.assign(byName[unit.unit] ?? { enabled: "", group: "other" }, {
                unit: unit.unit, description: unit.description, active: unit.active, sub: unit.sub,
            })
        }

        for (const service of Object.values(byName)) {
            // An instance (foo@bar.service) of one's own template (foo@.service) is one's own too.
            const mine = own.has(service.unit) || own.has(service.unit.replace(/@[^.]*\.service$/, "@.service"))
            service.group = mine ? "mine" : "other"
        }

        // Own services first; then failed, running and stopped, each alphabetically.
        page.services = Object.values(byName).sort((a, b) => {
            if (a.group !== b.group)
                return a.group === "mine" ? -1 : 1
            const rank = page.stateRank(a.active) - page.stateRank(b.active)
            return rank !== 0 ? rank : a.unit.localeCompare(b.unit)
        })
        page.show()
    }

    function show() {
        const needle = page.filter.trim().toLowerCase()
        const rows = page.services.filter(s => {
            if (page.statusFilter === "running" && s.active !== "active")
                return false
            if (page.statusFilter === "failed" && s.active !== "failed")
                return false
            return !needle || s.unit.toLowerCase().includes(needle) || s.description.toLowerCase().includes(needle)
        })

        for (let i = 0; i < rows.length; i++) {
            if (i < serviceModel.count)
                serviceModel.set(i, rows[i])
            else
                serviceModel.append(rows[i])
        }
        if (serviceModel.count > rows.length)
            serviceModel.remove(rows.length, serviceModel.count - rows.length)
    }

    function run(verb, unit) {
        if (!page.isUser)
            return
        controller.verb = verb
        controller.unit = unit
        controller.command = ["systemctl", "--user", verb, "--", unit]
        controller.running = true
    }

    function openLogs(unit) {
        page.logsUnit = unit
        logText.text = "Loading…"
        loadLogs()
    }

    function loadLogs() {
        if (page.logsUnit === "" || logReader.running)
            return
        logReader.command = ["journalctl", "--user-unit=" + page.logsUnit, "-n", "300",
                             "--no-pager", "--no-hostname", "-o", "short"]
        logReader.running = true
    }

    function showMessage(text, isError) {
        page.message = text
        page.messageIsError = isError
        messageTimer.restart()
    }

    onActiveChanged: if (active) refresh()
    Component.onCompleted: if (active) refresh()
    onScopeChanged: {
        page.expandedUnit = ""
        page.services = []
        serviceModel.clear()
        refresh()
    }
    onStatusFilterChanged: show()
    onFilterChanged: show()

    ListModel {
        id: serviceModel
    }

    Process {
        id: lister

        property string scopeLoaded

        stdout: StdioCollector {
            onStreamFinished: page.parse(text, lister.scopeLoaded)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: page.active && page.logsUnit === ""
        onTriggered: {
            if (!serviceList.moving)
                page.refresh()
        }
    }

    Process {
        id: controller

        property string verb
        property string unit

        stderr: StdioCollector {
            id: controlErrors
        }

        onExited: exitCode => {
            const name = controller.unit.replace(/\.service$/, "")
            const done = { start: "Started ", stop: "Stopped ", restart: "Restarted " }
            if (exitCode === 0)
                page.showMessage(done[controller.verb] + name, false)
            else
                page.showMessage(controlErrors.text.trim().split("\n")[0] || "Could not " + controller.verb + " " + name, true)
            page.refresh()
        }
    }

    Process {
        id: logReader

        stdout: StdioCollector {
            onStreamFinished: {
                logText.text = text.trim() || "No log entries."
                Qt.callLater(() => logView.contentY = Math.max(0, logView.contentHeight - logView.height))
            }
        }
    }

    Timer {
        id: messageTimer
        interval: 5000
        onTriggered: page.message = ""
    }

    // Service list

    Item {
        anchors.fill: parent
        visible: page.logsUnit === ""

        Column {
            id: controls

            width: parent.width
            spacing: 10

            Row {
                id: scopeRow

                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { value: "user", label: "User services" },
                        { value: "system", label: "System services" },
                    ]

                    delegate: Chip {
                        required property var modelData

                        width: (scopeRow.width - scopeRow.spacing) / 2
                        text: modelData.label
                        selected: page.scope === modelData.value
                        onClicked: page.scope = modelData.value
                    }
                }
            }

            Row {
                id: statusRow

                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { value: "all", label: "All" },
                        { value: "running", label: "Running" },
                        { value: "failed", label: "Failed" },
                    ]

                    delegate: Chip {
                        required property var modelData

                        width: (statusRow.width - 2 * statusRow.spacing) / 3
                        text: modelData.label
                              + (modelData.value === "failed"
                                 ? " · " + page.services.filter(s => s.active === "failed").length : "")
                        selected: page.statusFilter === modelData.value
                        onClicked: page.statusFilter = modelData.value
                    }
                }
            }

            InputField {
                id: searchField

                width: parent.width
                placeholderText: "Filter services"

                onTextChanged: page.filter = text
            }

            Text {
                width: parent.width
                text: page.message !== ""
                      ? page.message
                      : serviceModel.count + " services"
                        + (page.isUser ? "" : " · read-only")
                color: page.message !== "" && page.messageIsError ? "#ff7777" : "#aaaaaa"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        ListView {
            id: serviceList

            anchors.top: controls.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            width: parent.width

            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: serviceModel

            ScrollBar.vertical: ScrollBar {
                width: 6
            }

            // "My services" first, then the rest. Only user services are split.
            section.property: page.isUser ? "group" : ""
            section.delegate: Item {
                id: sectionHeader

                required property string section
                readonly property bool mine: section === "mine"

                width: serviceList.width
                height: 34

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8

                    text: (sectionHeader.mine ? "My services" : "Other services") + " · "
                          + page.services.filter(s => s.group === sectionHeader.section).length
                          + (sectionHeader.mine ? "  ~/.config/systemd/user" : "")
                    color: sectionHeader.mine ? "#80bfff" : "#aaaaaa"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            delegate: Rectangle {
                id: row

                required property string unit
                required property string description
                required property string active
                required property string sub
                required property string enabled
                required property string group

                readonly property bool mine: page.isUser && group === "mine"
                readonly property bool expanded: page.isUser && page.expandedUnit === unit

                width: serviceList.width
                height: expanded ? 52 + 44 + 12 : 52
                radius: 10
                color: expanded || rowMouse.pressed ? "#262626" : mine ? "#1d232b" : "#1c1c1c"
                border.width: mine ? 1 : 0
                border.color: "#2c3e52"

                MouseArea {
                    id: rowMouse

                    width: parent.width
                    height: 52
                    enabled: page.isUser
                    onClicked: page.expandedUnit = row.expanded ? "" : row.unit
                }

                Rectangle {
                    id: dot

                    x: 14
                    y: (52 - height) / 2
                    width: 10
                    height: 10
                    radius: 5
                    color: page.statusColor(row.active)
                }

                Column {
                    anchors.left: dot.right
                    anchors.leftMargin: 12
                    anchors.right: stateText.left
                    anchors.rightMargin: 8
                    y: (52 - height) / 2
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.unit.replace(/\.service$/, "")
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: row.description || row.enabled
                        color: "#888888"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: stateText

                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: (52 - height) / 2

                    text: row.sub
                    color: row.active === "failed" ? "#ff7777" : "#aaaaaa"
                    font.pixelSize: 12
                }

                Row {
                    id: actions

                    visible: row.expanded
                    x: 14
                    y: 52
                    width: parent.width - 28
                    spacing: 6

                    Repeater {
                        model: [
                            { verb: "start", label: "Start" },
                            { verb: "stop", label: "Stop" },
                            { verb: "restart", label: "Restart" },
                            { verb: "logs", label: "Logs" },
                        ]

                        delegate: ActionButton {
                            required property var modelData

                            width: (actions.width - 3 * actions.spacing) / 4
                            text: modelData.label
                            onClicked: modelData.verb === "logs"
                                       ? page.openLogs(row.unit)
                                       : page.run(modelData.verb, row.unit)
                        }
                    }
                }
            }
        }
    }

    // Logs of one user service

    Item {
        anchors.fill: parent
        visible: page.logsUnit !== ""

        Row {
            id: logHeader

            width: parent.width
            spacing: 8

            ActionButton {
                width: 88
                text: "‹ Back"
                onClicked: page.logsUnit = ""
            }

            Text {
                width: parent.width - 88 - 104 - 16
                height: 44
                verticalAlignment: Text.AlignVCenter
                text: page.logsUnit.replace(/\.service$/, "")
                color: "white"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideMiddle
            }

            ActionButton {
                width: 104
                text: "Refresh"
                onClicked: page.loadLogs()
            }
        }

        Rectangle {
            anchors.top: logHeader.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            width: parent.width
            radius: 10
            color: "#141414"

            Flickable {
                id: logView

                anchors.fill: parent
                anchors.margins: 10
                clip: true
                contentHeight: logText.height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 6
                }

                Text {
                    id: logText

                    width: logView.width
                    color: "#cccccc"
                    font.pixelSize: 11
                    font.family: "monospace"
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
