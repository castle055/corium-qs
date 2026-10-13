import QtQuick
import QtQuick.Layouts
import "utils"
import "../services"
import "connectivity"

// Wi-Fi, Bluetooth and airplane mode.
BarPopupButton {
    id: root

    implicitWidth: barRow.implicitWidth + 24
    implicitHeight: 48

    // The Wi-Fi page has password fields.
    keyboardFocus: true

    // Which tab the popup shows: "wifi" or "bluetooth". Kept between openings.
    property string page: "wifi"

    property bool airplaneBusy: false
    property string airplaneError: ""

    function icon(codepoint) {
        return String.fromCodePoint(codepoint)
    }

    function tabLabel(codepoint, label) {
        return String.fromCodePoint(codepoint) + "  " + label
    }

    // Short statuses for the quick toggles.
    readonly property string wifiStatus: {
        if (!Iwd.available)
            return "Unavailable"
        if (!Iwd.powered)
            return "Off"
        if (Iwd.state === "connecting")
            return "Connecting…"
        return Iwd.connectedNetwork?.name ?? "Not connected"
    }

    readonly property string bluetoothStatus: {
        const connected = bluetoothPage.connectedDevices
        if (!bluetoothPage.adapter)
            return "Unavailable"
        if (!bluetoothPage.powered)
            return "Off"
        if (connected.length === 1)
            return connected[0].name
        if (connected.length > 1)
            return connected.length + " devices"
        return "On"
    }

    function toggleAirplaneMode() {
        if (airplaneBusy || !Rfkill.available)
            return
        airplaneBusy = true
        airplaneError = ""
        Rfkill.setAirplaneMode(!Rfkill.airplaneMode, (ok, errorText) => {
            root.airplaneBusy = false
            if (!ok)
                root.airplaneError = errorText
        })
    }

    onPopupVisibleChanged: {
        if (popupVisible) {
            airplaneError = ""
            wifiPage.reset()
            bluetoothPage.reset()
        }
    }

    // ------------------------------------------------------------------
    // Bar icons
    // ------------------------------------------------------------------

    Row {
        id: barRow

        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: Rfkill.airplaneMode
            text: root.icon(0xF001D)
            color: "white"
            font.pixelSize: 18
        }

        Text {
            visible: !Rfkill.airplaneMode
            text: wifiPage.statusIcon
            color: Iwd.connectedNetwork && Iwd.powered ? "white" : "gray"
            font.pixelSize: 18

            SequentialAnimation on opacity {
                running: Iwd.state === "connecting"
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation { to: 0.3; duration: 500 }
                NumberAnimation { to: 1; duration: 500 }
            }
        }

        Text {
            visible: !Rfkill.airplaneMode
            text: bluetoothPage.statusIcon
            color: bluetoothPage.connectedDevices.length > 0
                   ? "white"
                   : bluetoothPage.powered ? "#aaaaaa" : "gray"
            font.pixelSize: 18
        }
    }

    // ------------------------------------------------------------------
    // Popup
    // ------------------------------------------------------------------

    popup: Rectangle {
        implicitWidth: 400
        implicitHeight: content.implicitHeight + 36

        color: "transparent"

        ColumnLayout {
            id: content

            x: 18
            y: 18
            width: parent.width - 36

            spacing: 12

            // Quick toggles

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                QuickToggle {
                    glyph: wifiPage.statusIcon
                    label: "Wi-Fi"
                    status: root.wifiStatus
                    checked: Iwd.powered
                    busy: wifiPage.busy
                    enabled: wifiPage.canTogglePower

                    onClicked: wifiPage.togglePower(() => root.page = "wifi")
                }

                QuickToggle {
                    glyph: bluetoothPage.statusIcon
                    label: "Bluetooth"
                    status: root.bluetoothStatus
                    checked: bluetoothPage.powered
                    busy: bluetoothPage.switching
                    enabled: bluetoothPage.adapter !== null

                    onClicked: bluetoothPage.togglePower(() => root.page = "bluetooth")
                }

                QuickToggle {
                    glyph: root.icon(Rfkill.airplaneMode ? 0xF001D : 0xF001E)
                    label: "Airplane"
                    status: Rfkill.airplaneMode ? "On" : "Off"
                    checked: Rfkill.airplaneMode
                    busy: root.airplaneBusy
                    enabled: Rfkill.available

                    onClicked: root.toggleAirplaneMode()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""

                text: root.airplaneError !== ""
                      ? root.airplaneError
                      : Rfkill.hardBlocked ? "A hardware switch is turning the radios off." : ""
                color: root.airplaneError !== "" ? "#ff5555" : "#ffaa00"
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            TabSwitcher {
                Layout.fillWidth: true

                model: [
                    { value: "wifi", label: root.tabLabel(0xF05A9, "Wi-Fi") },
                    { value: "bluetooth", label: root.tabLabel(0xF00AF, "Bluetooth")
                                                 + (bluetoothPage.connectedDevices.length > 0
                                                    ? " · " + bluetoothPage.connectedDevices.length
                                                    : "") }
                ]
                current: root.page
                onActivated: value => root.page = value
            }

            WifiPage {
                id: wifiPage

                Layout.fillWidth: true
                visible: root.page === "wifi"
                active: root.popupVisible && visible
            }

            BluetoothPage {
                id: bluetoothPage

                Layout.fillWidth: true
                visible: root.page === "bluetooth"
                active: root.popupVisible && visible
            }
        }
    }

    // ------------------------------------------------------------------
    // Helper components
    // ------------------------------------------------------------------

    // A tile that switches something on or off: glyph, name and a short
    // status, filled with the accent colour while on.
    component QuickToggle: Rectangle {
        id: tile

        property string glyph
        property string label
        property string status
        property bool checked: false
        // Pulses while switching.
        property bool busy: false

        signal clicked()

        Layout.fillWidth: true
        // Equal widths, whatever the text.
        Layout.preferredWidth: 1
        implicitHeight: 84
        radius: 14
        opacity: enabled ? 1 : 0.4

        color: checked
               ? (tileMouse.pressed ? "#99ccff" : "#80bfff")
               : (tileMouse.pressed ? "#353535" : "#1c1c1c")

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 4

            Text {
                text: tile.glyph
                color: tile.checked ? "#202020" : "white"
                font.pixelSize: 22

                SequentialAnimation on opacity {
                    running: tile.busy
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }

            Text {
                width: parent.width
                text: tile.label
                color: tile.checked ? "#202020" : "white"
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.status
                color: tile.checked ? "#203850" : "#aaaaaa"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tileMouse

            anchors.fill: parent
            onClicked: tile.clicked()
        }
    }
}
