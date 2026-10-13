pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../utils"
import "../../services"

// The Bluetooth tab of the connectivity popup: paired and nearby devices, and
// a page per paired device.
ColumnLayout {
    id: root

    // The popup is open and this tab is shown. Looks for devices while true.
    property bool active: false

    spacing: 12

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
    readonly property bool powered: adapter?.enabled ?? false

    readonly property var devices: adapter?.devices.values ?? []
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property var pairedDevices: devices.filter(d => d.paired)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Devices without a name are mostly beacons and other things you can't pair with.
    readonly property var nearbyDevices: devices.filter(d => !d.paired && d.deviceName !== "")
        .sort((a, b) => a.name.localeCompare(b.name))

    // The list, or the page for one paired device.
    property string page: "list"
    property BluetoothDevice selected: null

    // The device being paired or connected from here, followed until it
    // succeeds or fails: Quickshell's calls don't report errors themselves.
    property BluetoothDevice pending: null
    // "pair" or "connect"
    property string pendingAction: ""

    property string message: ""
    property bool messageIsError: false

    function icon(codepoint) {
        return String.fromCodePoint(codepoint)
    }

    // BlueZ icon names (freedesktop names) to glyphs.
    function deviceIcon(device) {
        switch (device.icon) {
        case "audio-headset": return icon(0xF02CE)
        case "audio-headphones": return icon(0xF02CB)
        case "audio-card": return icon(0xF04C3)
        case "input-keyboard": return icon(0xF030C)
        case "input-mouse": return icon(0xF037D)
        case "input-gaming": return icon(0xF0297)
        case "input-tablet": return icon(0xF04F6)
        case "phone": return icon(0xF011C)
        case "computer": return icon(0xF0322)
        case "video-display": return icon(0xF0379)
        case "printer": return icon(0xF042A)
        case "camera-photo":
        case "camera-video": return icon(0xF0100)
        }
        return icon(0xF00AF)
    }

    function deviceStatus(device) {
        if (pending === device && pendingAction === "pair")
            return "Pairing…"
        switch (device.state) {
        case BluetoothDeviceState.Connecting: return "Connecting…"
        case BluetoothDeviceState.Disconnecting: return "Disconnecting…"
        case BluetoothDeviceState.Connected:
            return device.batteryAvailable ? "Connected · " + Math.round(device.battery * 100) + "%" : "Connected"
        }
        return device.paired ? "Not connected" : ""
    }

    // Also shown in the bar.
    readonly property string statusIcon: {
        if (!adapter || !powered)
            return icon(0xF00B2)
        if (connectedDevices.length > 0)
            return icon(0xF00B1)
        return icon(0xF00AF)
    }

    readonly property string statusText: {
        if (!adapter)
            return "Bluetooth isn't running"
        if (blocked)
            return "Off (blocked)"
        switch (adapter.state) {
        case BluetoothAdapterState.Enabling: return "Turning on…"
        case BluetoothAdapterState.Disabling: return "Turning off…"
        }
        if (!powered)
            return "Off"
        if (connectedDevices.length === 1)
            return "Connected to " + connectedDevices[0].name
        if (connectedDevices.length > 1)
            return connectedDevices.length + " devices connected"
        return "Not connected"
    }

    function showMessage(text, isError) {
        message = text
        messageIsError = isError
    }

    // Called when the popup opens.
    function reset() {
        backToList()
    }

    function openDetails(device) {
        selected = device
        showMessage("", false)
        page = "details"
    }

    function backToList() {
        page = "list"
        selected = null
        showMessage("", false)
    }

    function follow(device, action) {
        pending = device
        pendingAction = action
        showMessage("", false)
    }

    function finish(errorText) {
        pending = null
        pendingAction = ""
        if (errorText)
            showMessage(errorText, true)
    }

    // Tapping a device: paired ones connect or disconnect, others are paired
    // first, then trusted (so they reconnect on their own) and connected.
    function activate(device) {
        if (device.state === BluetoothDeviceState.Connecting
                || device.state === BluetoothDeviceState.Disconnecting
                || device.pairing)
            return

        if (device.connected) {
            device.disconnect()
        } else if (device.paired) {
            follow(device, "connect")
            device.connect()
        } else {
            follow(device, "pair")
            device.pair()
        }
    }

    function forget(device) {
        if (pending === device)
            finish("")
        if (selected === device)
            backToList()
        device.forget()
    }

    // Turning on or off is in progress.
    readonly property bool switching: adapter?.state === BluetoothAdapterState.Enabling
                                      || adapter?.state === BluetoothAdapterState.Disabling

    // onFailure runs if it didn't work; the error is shown on this page.
    function togglePower(onFailure) {
        if (!adapter || switching)
            return
        if (powered) {
            adapter.enabled = false
        } else if (blocked) {
            Rfkill.unblock("bluetooth", (ok, errorText) => {
                if (!ok) {
                    showMessage("Bluetooth is blocked. Check for a hardware switch, or run "
                                + "\"rfkill unblock bluetooth\".", true)
                    onFailure?.()
                    return
                }
                // BlueZ needs a moment to notice the radio is back.
                enableAfterUnblock.restart()
            })
        } else {
            adapter.enabled = true
        }
    }

    Timer {
        id: enableAfterUnblock

        interval: 500

        onTriggered: {
            if (root.adapter)
                root.adapter.enabled = true
        }
    }

    // Look for devices while the list can be seen. Discovery uses power and
    // slows down other Bluetooth traffic, so it stops when the tab is hidden.
    // `enabled` turns on before the radio is ready, so wait for the Enabled state.
    readonly property bool shouldDiscover: active && page === "list"
                                           && adapter?.state === BluetoothAdapterState.Enabled

    onShouldDiscoverChanged: {
        if (adapter && adapter.discovering !== shouldDiscover && (powered || !shouldDiscover))
            adapter.discovering = shouldDiscover
    }

    // ------------------------------------------------------------------
    // Following pairing and connecting
    // ------------------------------------------------------------------

    Connections {
        target: root.pending

        function onPairedChanged() {
            const device = root.pending
            if (root.pendingAction !== "pair" || !device.paired)
                return
            device.trusted = true
            root.follow(device, "connect")
            device.connect()
        }

        function onPairingChanged() {
            // `pairing` can turn off just before `paired` turns on, so check
            // again a moment later.
            if (root.pendingAction === "pair" && !root.pending.pairing)
                pairCheck.restart()
        }

        function onStateChanged() {
            const device = root.pending
            if (root.pendingAction !== "connect")
                return
            if (device.state === BluetoothDeviceState.Connected)
                root.finish("")
            else if (device.state === BluetoothDeviceState.Disconnected)
                root.finish("Couldn't connect to " + device.name + ". Make sure it's on and in range.")
        }
    }

    Timer {
        id: pairCheck

        interval: 1000

        onTriggered: {
            const device = root.pending
            if (root.pendingAction === "pair" && device && !device.pairing && !device.paired)
                root.finish("Couldn't pair with " + device.name + ". Put it in pairing mode and "
                            + "try again. Devices that ask for a PIN aren't supported here.")
        }
    }

    // ------------------------------------------------------
    // Header
    // ------------------------------------------------------

    // Power is switched by the tile above the tabs.
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Text {
            Layout.fillWidth: true
            leftPadding: 4
            text: root.statusText
            color: "#aaaaaa"
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        IconButton {
            visible: root.powered && root.page === "list"
            // Shows whether it's looking for devices; tap to start or stop.
            text: root.icon(0xF0437)
            textSize: 18
            opacity: root.adapter?.discovering ? 1 : 0.4

            onClicked: root.adapter.discovering = !root.adapter.discovering
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.message !== ""

        text: root.message
        color: root.messageIsError ? "#ff5555" : "#aaaaaa"
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    Text {
        Layout.fillWidth: true
        visible: !root.adapter

        text: "Couldn't reach BlueZ over D-Bus. Make sure the bluez package is installed and "
              + "bluetooth.service is running."
        color: "#aaaaaa"
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    // ------------------------------------------------------
    // Device list
    // ------------------------------------------------------

    Flickable {
        id: deviceList

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        visible: root.page === "list" && root.powered

        contentHeight: deviceColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: deviceList.contentHeight > deviceList.height
                    ? ScrollBar.AsNeeded
                    : ScrollBar.AlwaysOff
        }

        Column {
            id: deviceColumn

            width: deviceList.width
            spacing: 2

            SectionLabel {
                visible: root.pairedDevices.length > 0
                text: "My devices"
            }

            Repeater {
                model: root.pairedDevices

                delegate: DeviceRow {
                    width: deviceColumn.width
                }
            }

            SectionLabel {
                text: "Nearby devices"
            }

            Text {
                visible: root.nearbyDevices.length === 0
                leftPadding: 10
                bottomPadding: 6

                text: root.adapter?.discovering ? "Looking for devices…" : "No devices found"
                color: "#777777"
                font.pixelSize: 13
            }

            Repeater {
                model: root.nearbyDevices

                delegate: DeviceRow {
                    width: deviceColumn.width
                }
            }
        }
    }

    // ------------------------------------------------------
    // Device page
    // ------------------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.page === "details" && root.selected !== null
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            IconButton {
                text: root.icon(0xF0141)

                onClicked: root.backToList()
            }

            Text {
                text: root.selected ? root.deviceIcon(root.selected) : ""
                color: "white"
                font.pixelSize: 22
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true

                    text: root.selected?.name ?? ""
                    color: "white"
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true

                    text: root.selected
                          ? root.deviceStatus(root.selected) + " · " + root.selected.address
                          : ""
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ActionButton {
                text: root.selected?.connected ? "Disconnect" : "Connect"
                primary: !(root.selected?.connected ?? false)
                enabled: root.selected?.state === BluetoothDeviceState.Connected
                         || root.selected?.state === BluetoothDeviceState.Disconnected

                onClicked: root.activate(root.selected)
            }

            ActionButton {
                text: "Forget"
                danger: true

                onClicked: root.forget(root.selected)
            }

            Item {
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Connect automatically"
                    color: "white"
                    font.pixelSize: 13
                }

                Text {
                    Layout.fillWidth: true
                    text: "Let it connect on its own when it's turned on nearby."
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }

            Toggle {
                checked: root.selected?.trusted ?? false

                onToggled: root.selected.trusted = !root.selected.trusted
            }
        }
    }

    // ------------------------------------------------------------------
    // Helper components
    // ------------------------------------------------------------------

    component SectionLabel: Text {
        topPadding: 6
        bottomPadding: 4
        leftPadding: 10
        color: "#aaaaaa"
        font.pixelSize: 12
    }

    component DeviceRow: Rectangle {
        id: deviceRow

        required property BluetoothDevice modelData

        readonly property bool waiting: modelData.pairing
                                        || modelData.state === BluetoothDeviceState.Connecting
                                        || modelData.state === BluetoothDeviceState.Disconnecting
                                        || (root.pending === modelData && root.pendingAction === "pair")

        height: 42
        radius: 6

        color: rowMouse.containsMouse
               ? "#353535"
               : modelData.connected ? "#292929" : "transparent"

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.activate(deviceRow.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 4
            spacing: 10

            Text {
                text: root.deviceIcon(deviceRow.modelData)
                color: "white"
                font.pixelSize: 16

                SequentialAnimation on opacity {
                    running: deviceRow.waiting
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }

            Text {
                Layout.fillWidth: true

                text: deviceRow.modelData.name
                color: "white"
                font.pixelSize: 13
                font.bold: deviceRow.modelData.connected
                elide: Text.ElideRight
            }

            Text {
                text: root.deviceStatus(deviceRow.modelData)
                color: "#aaaaaa"
                font.pixelSize: 10
            }

            IconButton {
                visible: deviceRow.modelData.paired
                text: root.icon(0xF0142)
                textSize: 16
                implicitWidth: 28
                implicitHeight: 28

                onClicked: root.openDetails(deviceRow.modelData)
            }
        }
    }
}
