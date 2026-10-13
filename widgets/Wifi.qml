import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "utils"
import "../services"

BarPopupButton {
    id: root

    implicitWidth: 48
    implicitHeight: 48

    keyboardFocus: true

    // The popup shows either the network list or the page for one network.
    property string page: "list"
    property string selectedPath: ""
    // Last known state of the selected network, kept in case it drops out of the scan.
    property var selectedSnapshot: null
    readonly property var selected: Iwd.networks.find(n => n.path === selectedPath) ?? selectedSnapshot

    property bool editingCredentials: false
    property bool confirmForget: false
    readonly property bool showForm: selected !== null
                                     && (selected.type === "psk" || selected.type === "8021x")
                                     && (editingCredentials || selected.knownPath === "")

    property bool busy: false
    property string busyText: ""
    property string message: ""
    property bool messageIsError: false

    function icon(codepoint) {
        return String.fromCodePoint(codepoint)
    }

    function strengthIcon(strength) {
        return icon([0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928][Math.max(0, Math.min(4, strength))])
    }

    function securityLabel(type) {
        switch (type) {
        case "open": return "Open"
        case "psk": return "WPA Personal"
        case "8021x": return "WPA Enterprise (802.1X)"
        case "wep": return "WEP"
        }
        return type
    }

    readonly property string barIcon: {
        if (!Iwd.available)
            return icon(0xF092B)
        if (!Iwd.powered)
            return icon(0xF092E)
        if (Iwd.connectedNetwork)
            return strengthIcon(Iwd.connectedNetwork.strength)
        return icon(0xF092F)
    }

    readonly property string statusText: {
        if (!Iwd.available)
            return "iwd is not running"
        if (!Iwd.hasDevice && Iwd.adapterPath === "")
            return "No wireless device"
        if (!Iwd.powered)
            return "Off"

        const name = Iwd.connectedNetwork?.name ?? ""
        switch (Iwd.state) {
        case "connected": return "Connected to " + name
        case "connecting": return name !== "" ? "Connecting to " + name + "…" : "Connecting…"
        case "roaming": return "Roaming on " + name
        case "disconnecting": return "Disconnecting…"
        }
        return "Not connected"
    }

    function showMessage(text, isError) {
        message = text
        messageIsError = isError
    }

    /*
     * Runs action(callback) while showing busyText; on failure, onFailure(code)
     * runs before the error message is shown.
     */
    function perform(text, action, onSuccess, onFailure) {
        busy = true
        busyText = text
        showMessage("", false)

        action((ok, errorMessage, code) => {
            busy = false
            if (ok) {
                onSuccess?.()
            } else {
                onFailure?.(code)
                showMessage(errorMessage, true)
            }
        })
    }

    function openDetails(network, editing) {
        selectedPath = network.path
        selectedSnapshot = network
        editingCredentials = !!editing
        confirmForget = false
        passwordField.text = ""
        eapPasswordField.text = ""
        showMessage("", false)
        page = "details"
    }

    function backToList() {
        page = "list"
        editingCredentials = false
        confirmForget = false
        passwordField.text = ""
        eapPasswordField.text = ""
        showMessage("", false)
    }

    function needsCredentials(network, code) {
        return network.type !== "open"
            && ["NoAgent", "NotConfigured", "Failed", "InvalidFormat"].includes(code)
    }

    // Clicking a network in the list.
    function activate(network) {
        if (network.connected || network.type === "wep") {
            openDetails(network, false)
        } else if (network.knownPath !== "" || network.type === "open") {
            perform("Connecting to " + network.name + "…",
                    callback => Iwd.connectNetwork(network, callback),
                    null,
                    code => {
                        if (needsCredentials(network, code))
                            openDetails(network, true)
                    })
        } else {
            openDetails(network, false)
        }
    }

    function connectSelected() {
        const network = selected
        if (!network)
            return

        const done = () => backToList()

        if (showForm && network.type === "psk") {
            if (passwordField.text === "") {
                showMessage("Enter the network password.", true)
                return
            }
            const passphrase = passwordField.text
            perform("Connecting to " + network.name + "…",
                    callback => Iwd.connectWithPassphrase(network, passphrase, callback), done)
        } else if (showForm && network.type === "8021x") {
            const config = {
                username: eapUserField.text,
                password: eapPasswordField.text,
                anonymousIdentity: eapAnonymousField.text,
                method: eapMethod.currentValue,
                caMode: caMode.currentValue,
                caPath: caPathField.text,
                domain: eapDomainField.text
            }
            perform("Checking settings…",
                    callback => Iwd.provisionEnterprise(network, config, callback,
                                                        text => root.busyText = text),
                    done)
        } else {
            perform("Connecting to " + network.name + "…",
                    callback => Iwd.connectNetwork(network, callback),
                    done,
                    code => {
                        if (needsCredentials(network, code))
                            editingCredentials = true
                    })
        }
    }

    function disconnectSelected() {
        perform("Disconnecting…", callback => Iwd.disconnect(callback))
    }

    function forgetSelected() {
        const network = selected
        // Forgetting an enterprise network deletes its provisioning file; confirm first.
        if (network.type === "8021x" && !confirmForget) {
            confirmForget = true
            return
        }
        perform("Forgetting " + network.name + "…",
                callback => Iwd.forget(network, callback),
                () => backToList())
    }

    function togglePower() {
        const on = !Iwd.powered
        perform(on ? "Turning Wi-Fi on…" : "Turning Wi-Fi off…",
                callback => Iwd.setPowered(on, callback))
    }

    onPopupVisibleChanged: {
        if (popupVisible) {
            if (!busy)
                backToList()
            Iwd.scan()
        }
    }

    // Keep the list fresh while the popup is open.
    Timer {
        interval: 15000
        running: root.popupVisible && Iwd.powered
        repeat: true

        onTriggered: Iwd.scan()
    }

    // ------------------------------------------------------------------
    // Bar icon
    // ------------------------------------------------------------------

    Text {
        anchors.centerIn: parent

        text: root.barIcon
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

            // ------------------------------------------------------
            // Header
            // ------------------------------------------------------

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: root.barIcon
                    color: Iwd.powered ? "white" : "gray"
                    font.pixelSize: 28
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Wi-Fi"
                        color: "white"
                        font.pixelSize: 20
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.statusText
                        color: "#aaaaaa"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    visible: Iwd.powered
                    text: Iwd.scanning ? root.icon(0xF0453) : root.icon(0xF0450)
                    enabled: !Iwd.scanning

                    onClicked: Iwd.scan()
                }

                Toggle {
                    visible: Iwd.available && (Iwd.hasDevice || Iwd.adapterPath !== "")
                    checked: Iwd.powered
                    enabled: !root.busy

                    onToggled: root.togglePower()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: "#404040"
            }

            Text {
                Layout.fillWidth: true
                visible: root.busy || root.message !== ""

                text: root.busy ? root.busyText : root.message
                color: !root.busy && root.messageIsError ? "#ff5555" : "#aaaaaa"
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: !Iwd.available

                text: "Couldn't reach iwd over D-Bus. Make sure iwd.service is running."
                color: "#aaaaaa"
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            // ------------------------------------------------------
            // Network list
            // ------------------------------------------------------

            Text {
                visible: root.page === "list" && Iwd.powered && Iwd.networks.length === 0

                text: Iwd.scanning ? "Scanning…" : "No networks found"
                color: "#777777"
                font.pixelSize: 13
            }

            Flickable {
                id: networkList

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 380)
                visible: root.page === "list" && Iwd.powered && Iwd.networks.length > 0

                contentHeight: networkColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: networkList.contentHeight > networkList.height
                            ? ScrollBar.AsNeeded
                            : ScrollBar.AlwaysOff
                }

                Column {
                    id: networkColumn

                    width: networkList.width
                    spacing: 2

                    Repeater {
                        model: Iwd.networks

                        delegate: Rectangle {
                            id: networkRow

                            required property var modelData

                            readonly property bool connecting: Iwd.state === "connecting"
                                                               && Iwd.connectedPath === modelData.path

                            width: networkColumn.width
                            height: 42
                            radius: 6

                            color: rowMouse.containsMouse
                                   ? "#353535"
                                   : modelData.connected ? "#292929" : "transparent"

                            MouseArea {
                                id: rowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.busy

                                onClicked: root.activate(networkRow.modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 4
                                spacing: 10

                                Text {
                                    text: root.strengthIcon(networkRow.modelData.strength)
                                    color: "white"
                                    font.pixelSize: 16
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text: networkRow.modelData.name
                                    color: "white"
                                    font.pixelSize: 13
                                    font.bold: networkRow.modelData.connected
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: networkRow.connecting
                                          ? "Connecting…"
                                          : networkRow.modelData.connected
                                            ? "Connected"
                                            : networkRow.modelData.knownPath !== "" ? "Saved" : ""
                                    color: "#aaaaaa"
                                    font.pixelSize: 10
                                }

                                Text {
                                    visible: networkRow.modelData.type !== "open"
                                    text: networkRow.modelData.type === "8021x"
                                          ? root.icon(0xF0483)
                                          : root.icon(0xF033E)
                                    color: "#aaaaaa"
                                    font.pixelSize: 12
                                }

                                IconButton {
                                    visible: networkRow.modelData.knownPath !== ""
                                             || networkRow.modelData.connected
                                    text: root.icon(0xF0142)
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    enabled: !root.busy

                                    onClicked: root.openDetails(networkRow.modelData, false)
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------
            // Network page
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
                        enabled: !root.busy

                        onClicked: root.backToList()
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

                            text: {
                                const network = root.selected
                                if (!network)
                                    return ""
                                const parts = [root.securityLabel(network.type)]
                                if (network.connected)
                                    parts.push("Connected")
                                else if (network.knownPath !== "")
                                    parts.push("Saved")
                                if (network.signal !== null)
                                    parts.push(Math.round(network.signal / 100) + " dBm")
                                return parts.join(" · ")
                            }
                            color: "#aaaaaa"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.selected?.type === "wep"

                    text: "iwd doesn't support WEP networks."
                    color: "#aaaaaa"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                // Saved or connected network
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.selected !== null && root.selected.type !== "wep" && !root.showForm
                    spacing: 8

                    ActionButton {
                        text: root.selected?.connected ? "Disconnect" : "Connect"
                        primary: !root.selected?.connected
                        enabled: !root.busy

                        onClicked: root.selected.connected ? root.disconnectSelected() : root.connectSelected()
                    }

                    ActionButton {
                        visible: (root.selected?.knownPath ?? "") !== ""
                        text: root.confirmForget ? "Confirm forget" : "Forget"
                        danger: true
                        enabled: !root.busy

                        onClicked: root.forgetSelected()
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.confirmForget && !root.showForm

                    text: "This deletes the saved enterprise configuration, including your "
                          + "credentials. You'll need to enter them again to reconnect."
                    color: "#ffaa00"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }

                LinkText {
                    visible: root.selected !== null && root.selected.knownPath !== ""
                             && root.selected.type !== "open" && !root.showForm
                    text: root.selected?.type === "8021x" ? "Edit credentials…" : "Change password…"

                    onClicked: {
                        root.confirmForget = false
                        root.editingCredentials = true
                    }
                }

                // ----------------------------------------------
                // WPA Personal form
                // ----------------------------------------------

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showForm && root.selected.type === "psk"
                    spacing: 6

                    FieldLabel {
                        text: "Password"
                    }

                    PasswordField {
                        id: passwordField

                        onAccepted: root.connectSelected()
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: (root.selected?.knownPath ?? "") !== ""

                        text: "The saved password will be replaced."
                        color: "#aaaaaa"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }

                // ----------------------------------------------
                // WPA Enterprise (802.1X / eduroam) form
                // ----------------------------------------------

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showForm && root.selected.type === "8021x"
                    spacing: 6

                    Text {
                        Layout.fillWidth: true

                        text: ((root.selected?.knownPath ?? "") !== ""
                               ? "This replaces the saved configuration. "
                               : "")
                              + "Saving requires administrator authentication."
                        color: "#aaaaaa"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }

                    FieldLabel {
                        text: "Username"
                    }

                    Field {
                        id: eapUserField

                        placeholderText: root.selected?.name === "eduroam"
                                         ? "user@institution.edu"
                                         : "Username"
                    }

                    FieldLabel {
                        text: "Password"
                    }

                    PasswordField {
                        id: eapPasswordField

                        onAccepted: root.connectSelected()
                    }

                    FieldLabel {
                        text: "Authentication"
                    }

                    ComboBox {
                        id: eapMethod

                        Layout.fillWidth: true

                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: "PEAP / MSCHAPv2", value: "peap-mschapv2" },
                            { text: "TTLS / PAP", value: "ttls-pap" },
                            { text: "TTLS / MSCHAPv2", value: "ttls-mschapv2" }
                        ]
                    }

                    FieldLabel {
                        text: "CA certificate"
                    }

                    ComboBox {
                        id: caMode

                        Layout.fillWidth: true

                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { text: "System CA bundle", value: "system" },
                            { text: "Certificate file", value: "file" },
                            { text: "Don't validate (insecure)", value: "none" }
                        ]
                    }

                    Field {
                        id: caPathField

                        visible: caMode.currentValue === "file"
                        placeholderText: "~/Downloads/institution-ca.pem"
                    }

                    FieldLabel {
                        visible: caMode.currentValue !== "none"
                        text: caMode.currentValue === "system" ? "Server domain" : "Server domain (recommended)"
                    }

                    Field {
                        id: eapDomainField

                        visible: caMode.currentValue !== "none"
                        placeholderText: "radius.institution.edu"
                    }

                    Text {
                        Layout.fillWidth: true

                        text: caMode.currentValue === "none"
                              ? "Without validation, anyone broadcasting this network name can "
                                + "capture your password."
                              : "Only servers whose certificate matches this domain are trusted. "
                                + "Use * for one label (*.example.edu), separate several with ;."
                        color: caMode.currentValue === "none" ? "#ffaa00" : "#aaaaaa"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }

                    FieldLabel {
                        text: "Anonymous identity (optional)"
                    }

                    Field {
                        id: eapAnonymousField

                        placeholderText: Iwd.defaultAnonymousIdentity(eapUserField.text.trim())
                                         || "anonymous@institution.edu"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.showForm
                    spacing: 8

                    ActionButton {
                        text: "Connect"
                        primary: true
                        enabled: !root.busy

                        onClicked: root.connectSelected()
                    }

                    ActionButton {
                        visible: root.editingCredentials && (root.selected?.knownPath ?? "") !== ""
                        text: "Cancel"
                        enabled: !root.busy

                        onClicked: root.editingCredentials = false
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Helper components
    // ------------------------------------------------------------------

    component ActionButton: Rectangle {
        id: button

        property string text
        property bool primary: false
        property bool danger: false

        signal clicked()

        implicitWidth: Math.max(96, label.implicitWidth + 24)
        implicitHeight: 34
        radius: 6
        opacity: enabled ? 1 : 0.4

        color: buttonMouse.pressed
               ? "#505050"
               : buttonMouse.containsMouse
                 ? "#404040"
                 : primary ? "#353535" : "#292929"

        border.width: primary ? 1 : 0
        border.color: "#777777"

        Text {
            id: label

            anchors.centerIn: parent

            text: button.text
            color: button.danger ? "#ff7777" : "white"
            font.pixelSize: 12
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true

            onClicked: button.clicked()
        }
    }

    component IconButton: Rectangle {
        id: iconButton

        property string text

        signal clicked()

        implicitWidth: 32
        implicitHeight: 32
        radius: width / 2
        opacity: enabled ? 1 : 0.5

        color: iconMouse.pressed
               ? "#505050"
               : iconMouse.containsMouse ? "#353535" : "transparent"

        Text {
            anchors.centerIn: parent

            text: iconButton.text
            color: "white"
            font.pixelSize: 16
        }

        MouseArea {
            id: iconMouse

            anchors.fill: parent
            hoverEnabled: true

            onClicked: iconButton.clicked()
        }
    }

    component Toggle: Rectangle {
        id: toggle

        property bool checked: false

        signal toggled()

        implicitWidth: 40
        implicitHeight: 22
        radius: height / 2
        opacity: enabled ? 1 : 0.4

        color: checked ? "#80bfff" : "#404040"

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: toggle.checked ? toggle.width - width - 3 : 3

            color: "white"

            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: toggle.toggled()
        }
    }

    component LinkText: Text {
        id: link

        signal clicked()

        color: linkMouse.containsMouse ? "white" : "#80bfff"
        font.pixelSize: 12

        MouseArea {
            id: linkMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: link.clicked()
        }
    }

    component FieldLabel: Text {
        color: "#aaaaaa"
        font.pixelSize: 12
    }

    component Field: TextField {
        id: field

        Layout.fillWidth: true
        implicitHeight: 36

        font.pixelSize: 13
        color: "white"
        placeholderTextColor: "#777777"
        selectByMouse: true

        background: Rectangle {
            radius: 6
            color: "#303030"
            border.width: 1
            border.color: field.activeFocus ? "#80bfff" : "#484848"
        }
    }

    component PasswordField: Field {
        id: passwordInput

        property bool revealed: false

        echoMode: revealed ? TextInput.Normal : TextInput.Password
        rightPadding: 36

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            text: String.fromCodePoint(passwordInput.revealed ? 0xF0209 : 0xF0208)
            color: "#aaaaaa"
            font.pixelSize: 16

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6

                onClicked: passwordInput.revealed = !passwordInput.revealed
            }
        }
    }
}
