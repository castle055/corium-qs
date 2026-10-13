pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "utils"
import "../services"
import "timers"

BarPopupButton {
    id: root

    implicitWidth: barRow.implicitWidth + 24
    implicitHeight: 48

    // The timers page has a name field.
    keyboardFocus: true

    // Which page the popup shows: "calendar", "timers" or "stopwatch". Kept between openings.
    property string page: "calendar"

    // Kept fresh while the popup is open, so the header and "today" stay correct.
    property date now: new Date()

    // The month shown in the calendar.
    property int shownMonth: now.getMonth()
    property int shownYear: now.getFullYear()

    readonly property bool showingCurrentMonth: shownMonth === now.getMonth()
                                               && shownYear === now.getFullYear()

    // The day whose events are listed, as YYYY-MM-DD.
    readonly property string todayKey: dayKey(now.getFullYear(), now.getMonth(), now.getDate())
    property string selectedKey: todayKey
    readonly property bool showingToday: showingCurrentMonth && selectedKey === todayKey

    // Events of the shown month (and a bit around it), by YYYY-MM-DD.
    property var eventsByDay: ({})
    readonly property var selectedEvents: eventsByDay[selectedKey] ?? []
    // Drops answers to requests made before the month changed.
    property int requestToken: 0

    function dayKey(year, month, day) {
        return year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")
    }

    function dateFromKey(key) {
        const [year, month, day] = key.split("-").map(Number)
        return new Date(year, month - 1, day)
    }

    function goToToday() {
        root.now = new Date()
        root.shownMonth = root.now.getMonth()
        root.shownYear = root.now.getFullYear()
        root.selectedKey = root.todayKey
        refresh()
    }

    function changeMonth(delta) {
        const d = new Date(root.shownYear, root.shownMonth + delta, 1)
        root.shownMonth = d.getMonth()
        root.shownYear = d.getFullYear()
        root.selectedKey = root.showingCurrentMonth
                ? root.todayKey
                : dayKey(root.shownYear, root.shownMonth, 1)
        refresh()
    }

    function refresh() {
        // The grid shows parts of the neighbouring months too.
        const from = new Date(root.shownYear, root.shownMonth, 1 - 14)
        const to = new Date(root.shownYear, root.shownMonth + 1, 14)
        const token = ++root.requestToken

        CalendarEvents.fetch(from, to, result => {
            if (token !== root.requestToken)
                return

            const byDay = {}
            for (const event of result?.events ?? []) {
                const calendar = result.calendars[event.calendar]
                event.color = calendar?.color || "#80bfff"
                for (const day of event.days) {
                    if (!byDay[day])
                        byDay[day] = []
                    byDay[day].push(event)
                }
            }
            root.eventsByDay = byDay
        })
    }

    function dayTitle(key) {
        const date = dateFromKey(key)
        const offset = Math.round((date - dateFromKey(root.todayKey)) / 86400000)
        const name = root.capitalize(date.toLocaleDateString(Qt.locale(), "dddd d MMMM"))
        if (offset === 0)
            return "Today · " + name
        if (offset === 1)
            return "Tomorrow · " + name
        if (offset === -1)
            return "Yesterday · " + name
        return name
    }

    // When an event happens on the given day: "All day", "09:30 – 10:15", or
    // "… – 02:00" for the last day of an event that started earlier.
    function timeLabel(event, key) {
        if (event.allDay)
            return "All day"
        const starts = event.start.slice(0, 10) === key ? event.start.slice(11, 16) : "…"
        const ends = event.end.slice(0, 10) === key ? event.end.slice(11, 16) : "…"
        return starts === ends ? starts : starts + " – " + ends
    }

    Connections {
        target: CalendarEvents

        function onUpdated() {
            if (root.popupVisible)
                root.refresh()
        }
    }

    // A tab label with a Nerd Font icon in front.
    function tabLabel(codepoint, label) {
        return String.fromCodePoint(codepoint) + "  " + label
    }

    function capitalize(text) {
        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    onPopupVisibleChanged: {
        if (popupVisible)
            goToToday()
    }

    Timer {
        interval: 1000
        running: root.popupVisible
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Amber while a timer is about to finish.
    readonly property color barColor: Timers.almostDone ? "#ffaa00" : "white"

    Row {
        id: barRow

        anchors.centerIn: parent
        spacing: 6

        // Shown while any timer is set; dimmed if they are all paused.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Timers.active

            text: String.fromCodePoint(0xF13AB)
            color: root.barColor
            opacity: Timers.counting ? 1 : 0.5
            font.pixelSize: 16

            Behavior on color {
                ColorAnimation { duration: 600 }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: Time.time
            font.bold: false
            font.pointSize: 12
            color: root.barColor

            Behavior on color {
                ColorAnimation { duration: 600 }
            }
        }
    }

    popup: Rectangle {
        implicitWidth: 400
        implicitHeight: popupColumn.implicitHeight + 32
        color: "transparent"

        Column {
            id: popupColumn

            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // Current time and date

            Column {
                width: parent.width
                spacing: 2

                Text {
                    text: root.capitalize(root.now.toLocaleDateString(Qt.locale(), "dddd"))
                    color: "#aaaaaa"
                    font.pixelSize: 13
                }

                Text {
                    text: root.now.toLocaleDateString(Qt.locale(), "d MMMM yyyy")
                    color: "white"
                    font.pixelSize: 22
                    font.bold: true
                }

                Text {
                    text: root.now.toLocaleTimeString(Qt.locale(), "HH:mm:ss")
                    color: "#aaaaaa"
                    font.pixelSize: 13
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#404040"
            }

            // Calendar / Timers switch

            TabSwitcher {
                width: parent.width

                model: [
                    { value: "calendar", label: root.tabLabel(0xF00ED, "Calendar") },
                    { value: "timers", label: root.tabLabel(0xF13AB, "Timers")
                                              + (Timers.active ? " · " + Timers.timers.length : "") },
                    { value: "stopwatch", label: root.tabLabel(0xF051B, "Stopwatch") },
                ]
                current: root.page
                onActivated: value => root.page = value
            }

            TimersPage {
                width: parent.width
                visible: root.page === "timers"
            }

            StopwatchPage {
                width: parent.width
                visible: root.page === "stopwatch"
                active: root.popupVisible && visible
            }

            Column {
                width: parent.width
                spacing: 14
                visible: root.page === "calendar"

                // Month navigation

                Item {
                    width: parent.width
                    height: 44

                    IconButton {
                        id: prevButton

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        text: "󰅁"
                        textSize: 22
                        onClicked: root.changeMonth(-1)
                    }

                    Text {
                        anchors.left: prevButton.right
                        anchors.right: nextButton.left
                        anchors.verticalCenter: parent.verticalCenter

                        horizontalAlignment: Text.AlignHCenter
                        text: root.capitalize(Qt.locale().standaloneMonthName(root.shownMonth))
                              + " " + root.shownYear
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    IconButton {
                        id: nextButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        text: "󰅂"
                        textSize: 22
                        onClicked: root.changeMonth(1)
                    }
                }

                // Calendar

                Item {
                    width: parent.width
                    height: dayNames.height + monthGrid.height

                    readonly property real weekColumnWidth: 30
                    readonly property real cellWidth: (width - weekColumnWidth) / 7

                    DayOfWeekRow {
                        id: dayNames

                        x: parent.weekColumnWidth
                        width: parent.width - parent.weekColumnWidth
                        height: 28
                        padding: 0
                        spacing: 0

                        locale: monthGrid.locale

                        delegate: Text {
                            required property string shortName

                            text: shortName
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: "#aaaaaa"
                            font.pixelSize: 12
                        }
                    }

                    WeekNumberColumn {
                        y: dayNames.height
                        width: parent.weekColumnWidth
                        height: monthGrid.height
                        padding: 0
                        spacing: 0

                        month: monthGrid.month
                        year: monthGrid.year
                        locale: monthGrid.locale

                        delegate: Text {
                            required property int weekNumber

                            text: weekNumber
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: "#666666"
                            font.pixelSize: 11
                        }
                    }

                    MonthGrid {
                        id: monthGrid

                        x: parent.weekColumnWidth
                        y: dayNames.height
                        width: parent.width - parent.weekColumnWidth
                        height: 6 * 44
                        padding: 0
                        spacing: 0

                        month: root.shownMonth
                        year: root.shownYear
                        // English names, but weeks start on Monday (the system is en_US).
                        locale: Qt.locale("en_GB")

                        delegate: Item {
                            id: dayCell

                            required property int day
                            required property int month
                            required property int year
                            required property bool today

                            readonly property bool inMonth: month === monthGrid.month
                            readonly property string key: root.dayKey(year, month, day)
                            readonly property bool selected: key === root.selectedKey
                            readonly property var events: root.eventsByDay[key] ?? []

                            Rectangle {
                                id: dayCircle

                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 4
                                height: width
                                radius: width / 2

                                color: dayCell.today
                                       ? "#80bfff"
                                       : dayTap.pressed ? "#404040" : "transparent"
                                border.width: dayCell.selected && !dayCell.today ? 2 : 0
                                border.color: "#80bfff"
                            }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -3

                                text: dayCell.day
                                color: dayCell.today
                                       ? "#202020"
                                       : dayCell.inMonth ? "white" : "#555555"
                                font.pixelSize: 14
                                font.bold: dayCell.today
                            }

                            // One dot per event, in its calendar's colour, up to three.
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: dayCircle.bottom
                                anchors.bottomMargin: 7
                                spacing: 3

                                Repeater {
                                    model: dayCell.events.slice(0, 3)

                                    delegate: Rectangle {
                                        required property var modelData

                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: dayCell.today ? "#202020" : modelData.color
                                        opacity: dayCell.inMonth ? 1 : 0.5
                                    }
                                }
                            }

                            TapHandler {
                                id: dayTap

                                onTapped: {
                                    root.selectedKey = dayCell.key
                                    if (!dayCell.inMonth) {
                                        // Also show that day's month, keeping the selection.
                                        const key = dayCell.key
                                        root.changeMonth(dayCell.year * 12 + dayCell.month
                                                         - (root.shownYear * 12 + root.shownMonth))
                                        root.selectedKey = key
                                    }
                                }
                            }
                        }

                        // Swipe left/right on the calendar to change month.
                        DragHandler {
                            target: null
                            xAxis.enabled: true
                            yAxis.enabled: false

                            onActiveChanged: {
                                if (active)
                                    return
                                if (centroid.scenePosition.x - centroid.scenePressPosition.x > 40)
                                    root.changeMonth(-1)
                                else if (centroid.scenePosition.x - centroid.scenePressPosition.x < -40)
                                    root.changeMonth(1)
                            }
                        }

                        WheelHandler {
                            onWheel: event => root.changeMonth(event.angleDelta.y > 0 ? -1 : 1)
                        }
                    }
                }

                // Events of the selected day

                Column {
                    width: parent.width
                    spacing: 8

                    visible: CalendarEvents.ready

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#404040"
                    }

                    Text {
                        width: parent.width
                        text: root.dayTitle(root.selectedKey)
                        color: "#aaaaaa"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.selectedEvents.length === 0
                        text: "No events"
                        color: "#777777"
                        font.pixelSize: 13
                    }

                    ListView {
                        id: eventList

                        width: parent.width
                        // Room for four events; scroll for more.
                        height: Math.min(contentHeight, 4 * 52 + 3 * spacing)
                        visible: count > 0

                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

                        model: root.selectedEvents

                        delegate: Rectangle {
                            id: eventRow

                            required property var modelData

                            width: eventList.width
                            height: 52
                            radius: 10
                            color: "#1c1c1c"

                            Rectangle {
                                id: colorBar

                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: parent.height - 18
                                radius: 2
                                color: eventRow.modelData.color
                            }

                            Column {
                                anchors.left: colorBar.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: eventRow.modelData.summary || "(No title)"
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: root.timeLabel(eventRow.modelData, root.selectedKey)
                                          + (eventRow.modelData.location ? " · " + eventRow.modelData.location : "")
                                    color: "#aaaaaa"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // Jump back to today

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 10

                    opacity: root.showingToday ? 0.4 : 1
                    color: todayMouse.pressed ? "#404040" : "#292929"

                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        color: "white"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: todayMouse

                        anchors.fill: parent
                        enabled: !root.showingToday
                        onClicked: root.goToToday()
                    }
                }
            }
        }
    }
}
