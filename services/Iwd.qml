pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wi-Fi state and actions backed by iwd's D-Bus API.
 *
 * State is read with busctl (JSON output) and refreshed whenever iwd emits a
 * D-Bus signal. Actions go through gdbus, except connecting with a new
 * passphrase, which needs an iwd agent and is delegated to iwctl.
 *
 * Enterprise (802.1X, e.g. eduroam) networks can only be connected once a
 * provisioning file exists in /var/lib/iwd, which is root-owned, so writing
 * one goes through pkexec.
 *
 * Action callbacks are called as callback(ok, message, code), where code is
 * the short iwd error name ("Failed", "NotConfigured", ...) on failure.
 */
Singleton {
    id: root

    readonly property string service: "net.connman.iwd"
    readonly property string storageDir: "/var/lib/iwd"
    readonly property string systemCaBundle: "/etc/ssl/certs/ca-certificates.crt"
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/corium/"

    property bool available: false
    property string adapterPath: ""
    property bool adapterPowered: false
    property string devicePath: ""
    property string deviceName: ""
    property bool devicePowered: false
    readonly property bool hasDevice: devicePath !== ""
    readonly property bool powered: adapterPowered && devicePowered

    property string stationPath: ""
    // connected, connecting, disconnected, disconnecting or roaming
    property string state: "disconnected"
    property bool scanning: false
    property string connectedPath: ""

    // [{ path, name, type, connected, knownPath, signal, strength }]
    // type is open, psk, 8021x or wep; signal is in 100 * dBm; strength is 1-4.
    property var networks: []
    readonly property var connectedNetwork: networks.find(n => n.path === connectedPath) ?? null

    property bool refreshing: false
    property bool refreshQueued: false

    function refresh() {
        if (refreshing) {
            refreshQueued = true
            return
        }
        refreshing = true

        run(["busctl", "--json=short", "call", service, "/",
             "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"],
            (exitCode, stdout, stderr) => {
                if (exitCode !== 0) {
                    applyObjects(null, {})
                    finishRefresh()
                    return
                }

                let objects
                try {
                    objects = JSON.parse(stdout).data[0]
                } catch (e) {
                    console.warn("Iwd: could not parse managed objects:", e)
                    finishRefresh()
                    return
                }

                const station = findStationPath(objects)
                if (station === "") {
                    applyObjects(objects, {})
                    finishRefresh()
                    return
                }

                run(["busctl", "--json=short", "call", service, station,
                     "net.connman.iwd.Station", "GetOrderedNetworks"],
                    (exitCode, stdout, stderr) => {
                        const signals = {}
                        if (exitCode === 0) {
                            try {
                                for (const [path, signal] of JSON.parse(stdout).data[0])
                                    signals[path] = signal
                            } catch (e) {
                                console.warn("Iwd: could not parse ordered networks:", e)
                            }
                        }
                        applyObjects(objects, signals)
                        finishRefresh()
                    })
            })
    }

    function finishRefresh() {
        refreshing = false
        if (refreshQueued) {
            refreshQueued = false
            refresh()
        }
    }

    function value(variant) {
        return variant === undefined ? undefined : variant.data
    }

    function findDevicePath(objects) {
        // Prefer a device in station mode; fall back to any device.
        let fallback = ""
        for (const path in objects) {
            if (!objects[path]["net.connman.iwd.Device"])
                continue
            if (objects[path]["net.connman.iwd.Station"])
                return path
            if (fallback === "")
                fallback = path
        }
        return fallback
    }

    function findStationPath(objects) {
        const path = findDevicePath(objects)
        return path !== "" && objects[path]["net.connman.iwd.Station"] ? path : ""
    }

    function strengthOf(signal) {
        if (signal === null || signal === undefined)
            return 1
        if (signal >= -6000)
            return 4
        if (signal >= -6700)
            return 3
        if (signal >= -7500)
            return 2
        return 1
    }

    function applyObjects(objects, signals) {
        if (objects === null) {
            available = false
            adapterPath = ""
            adapterPowered = false
            devicePath = ""
            deviceName = ""
            devicePowered = false
            stationPath = ""
            state = "disconnected"
            scanning = false
            connectedPath = ""
            networks = []
            return
        }

        available = true

        const device = findDevicePath(objects)
        const deviceProps = device !== "" ? objects[device]["net.connman.iwd.Device"] : null
        const stationProps = device !== "" ? objects[device]["net.connman.iwd.Station"] : null

        // When the adapter is powered off (e.g. rfkill), iwd removes its devices,
        // so look for an adapter independently of the device.
        let adapter = deviceProps ? value(deviceProps.Adapter) : ""
        if (!adapter) {
            for (const path in objects) {
                if (objects[path]["net.connman.iwd.Adapter"]) {
                    adapter = path
                    break
                }
            }
        }
        const adapterProps = adapter ? objects[adapter]["net.connman.iwd.Adapter"] : null

        adapterPath = adapter ?? ""
        adapterPowered = adapterProps ? !!value(adapterProps.Powered) : false
        devicePath = device
        deviceName = deviceProps ? value(deviceProps.Name) : ""
        devicePowered = deviceProps ? !!value(deviceProps.Powered) : false
        stationPath = stationProps ? device : ""
        state = stationProps ? value(stationProps.State) : "disconnected"
        scanning = stationProps ? !!value(stationProps.Scanning) : false
        connectedPath = stationProps ? (value(stationProps.ConnectedNetwork) ?? "") : ""

        const list = []
        for (const path in objects) {
            const network = objects[path]["net.connman.iwd.Network"]
            if (!network || value(network.Device) !== device)
                continue

            const signal = signals[path] ?? null
            list.push({
                path: path,
                name: value(network.Name),
                type: value(network.Type),
                connected: !!value(network.Connected),
                knownPath: value(network.KnownNetwork) ?? "",
                signal: signal,
                strength: strengthOf(signal)
            })
        }

        list.sort((a, b) => (b.connected - a.connected)
                  || ((b.signal ?? -100000) - (a.signal ?? -100000))
                  || a.name.localeCompare(b.name))

        networks = list
    }

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------

    function scan() {
        if (stationPath === "" || scanning)
            return
        // Busy / InProgress errors just mean iwd is already scanning.
        call(stationPath, "net.connman.iwd.Station", "Scan", [], 15, () => {})
    }

    function setPowered(on, callback) {
        const setDevice = () => {
            if (devicePath === "") {
                // Devices reappear shortly after the adapter powers on.
                delay(1000, () => {
                    if (devicePath === "") {
                        callback(true, "", "")
                        return
                    }
                    setProperty(devicePath, "net.connman.iwd.Device", "Powered", on, callback)
                })
                return
            }
            setProperty(devicePath, "net.connman.iwd.Device", "Powered", on, (ok, message, code) => {
                if (ok && on)
                    delay(500, scan)
                callback(ok, message, code)
            })
        }

        if (!on || adapterPowered) {
            setDevice()
            return
        }

        // The adapter is off, usually because of a soft rfkill block. Try to
        // lift it (logind normally gives the active session access to
        // /dev/rfkill), then power the adapter on.
        run(["rfkill", "unblock", "wlan"], () => {
            setProperty(adapterPath, "net.connman.iwd.Adapter", "Powered", true, (ok, message, code) => {
                if (!ok) {
                    callback(false, "Wi-Fi is blocked. Check for a hardware switch, or run "
                             + "\"rfkill unblock wlan\".", code)
                    return
                }
                delay(1000, setDevice)
            })
        })
    }

    function connectNetwork(network, callback) {
        call(network.path, "net.connman.iwd.Network", "Connect", [], 60, (ok, message, code) => {
            if (!ok && code === "Failed" && network.type === "8021x")
                message = enterpriseFailureMessage
            else if (!ok && code === "Failed" && network.type === "psk")
                message = "Connection failed. If the password has changed, enter it again."
            callback(ok, message, code)
        })
    }

    function connectWithPassphrase(network, passphrase, callback) {
        const connect = () => {
            // Note: iwctl only takes the passphrase as an argument, so it is
            // briefly visible in the process list.
            run(["iwctl", "--dont-ask", "--passphrase", passphrase,
                 "station", deviceName, "connect", network.name, network.type],
                (exitCode, stdout, stderr) => {
                    const output = (stdout + stderr).replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").trim()

                    if (exitCode === 0 && output === "") {
                        callback(true, "", "")
                    } else if (/invalid|format/i.test(output)) {
                        callback(false, "That password isn't valid for this network.", "InvalidFormat")
                    } else if (/fail/i.test(output)) {
                        callback(false, "Connection failed. Check the password and try again.", "Failed")
                    } else {
                        callback(false, output || "Connection failed.", "Failed")
                    }
                },
                { timeout: 90 })
        }

        // A saved passphrase takes precedence over --passphrase, so forget it first.
        if (network.knownPath)
            forget(network, () => connect())
        else
            connect()
    }

    function disconnect(callback) {
        call(stationPath, "net.connman.iwd.Station", "Disconnect", [], 15, callback)
    }

    function forget(network, callback) {
        // For 802.1X networks this also deletes the provisioning file.
        call(network.knownPath, "net.connman.iwd.KnownNetwork", "Forget", [], 15, callback)
    }

    // ------------------------------------------------------------------
    // Enterprise (802.1X) provisioning
    // ------------------------------------------------------------------

    readonly property string enterpriseFailureMessage:
        "Authentication failed. Check your username and password. If they are right, "
        + "the CA certificate or server domain may not match the network's RADIUS server."

    /*
     * config: {
     *   username, password, anonymousIdentity,
     *   method: "peap-mschapv2" | "ttls-pap" | "ttls-mschapv2",
     *   caMode: "system" | "file" | "none",
     *   caPath, domain
     * }
     * progress(text) is called as the steps advance.
     */
    function provisionEnterprise(network, config, callback, progress) {
        const error = validateEnterprise(network, config)
        if (error !== "") {
            callback(false, error, "InvalidArgs")
            return
        }

        prepareCaCertificate(network, config, (ok, message, caSource, caCert) => {
            if (!ok) {
                callback(false, message, "Certificate")
                return
            }

            progress?.("Waiting for administrator authentication…")

            const fileName = storageFileName(network, "8021x")
            const caDestination = caSource !== "" ? caCert : ""
            const script = 'set -eu\n'
                + 'umask 077\n'
                + 'dir="' + storageDir + '"\n'
                + 'if [ -n "$2" ]; then\n'
                + '  mkdir -p "$dir/certs"\n'
                + '  install -m 0644 "$2" "$3"\n'
                + 'fi\n'
                + 'tmp=$(mktemp "$dir/.corium-XXXXXX")\n'
                + 'cat > "$tmp"\n'
                + 'mv -f "$tmp" "$dir/$1"\n'

            // The file contents (including the password) go through stdin so
            // they never appear in the process list.
            run(["pkexec", "/bin/sh", "-c", script, "corium-iwd", fileName, caSource, caDestination],
                (exitCode, stdout, stderr) => {
                    if (exitCode !== 0) {
                        callback(false, pkexecFailureMessage(exitCode, stderr), "Authorization")
                        return
                    }

                    progress?.("Connecting to " + network.name + "…")
                    // iwd picks the new file up through inotify; give it a moment.
                    delay(1000, () => connectAfterProvisioning(network, 0, callback))
                },
                { input: enterpriseSettings(config, caCert), timeout: 300 })
        })
    }

    function validateEnterprise(network, config) {
        const fields = [config.username, config.password, config.anonymousIdentity,
                        config.caPath, config.domain]
        if (fields.some(field => /[\r\n]/.test(field ?? "")))
            return "Fields can't contain line breaks."

        if (config.username.trim() === "")
            return "Enter your username."
        if (config.password === "")
            return "Enter your password."
        if (network.name === "eduroam" && !config.username.includes("@"))
            return "eduroam usernames include your institution's realm, e.g. user@university.edu."

        if (config.caMode === "file" && config.caPath.trim() === "")
            return "Enter the path to the CA certificate."
        if (config.caMode === "system" && config.domain.trim() === "")
            return "Enter the server domain. With the system CA bundle, it is what stops any "
                   + "server with a public certificate from receiving your password."
        return ""
    }

    /*
     * callback(ok, message, caSource, caCert): caCert is the path iwd should
     * use (empty for no validation), caSource the local file to install there
     * (empty when nothing needs installing).
     */
    function prepareCaCertificate(network, config, callback) {
        if (config.caMode === "none") {
            callback(true, "", "", "")
            return
        }

        if (config.caMode === "system") {
            run(["test", "-r", systemCaBundle], (exitCode) => {
                if (exitCode !== 0)
                    callback(false, "The system CA bundle (" + systemCaBundle + ") is missing. "
                             + "Install ca-certificates or choose a certificate file.", "", "")
                else
                    callback(true, "", "", systemCaBundle)
            })
            return
        }

        let source = config.caPath.trim().replace(/^file:\/\//, "")
        if (source.startsWith("~/"))
            source = Quickshell.env("HOME") + source.substring(1)

        // iwd runs with ProtectHome=yes and can't read the user's files, so the
        // certificate is normalised to PEM here and installed into its state dir.
        const hex = ssidHex(network)
        const staged = cacheDir + "ca-" + hex + ".pem"
        const script = 'src="$1"; out="$2"\n'
            + 'command -v openssl >/dev/null || exit 14\n'
            + '[ -f "$src" ] && [ -r "$src" ] || exit 10\n'
            + 'mkdir -p "$(dirname "$out")" && rm -f "$out" || exit 13\n'
            + 'if openssl x509 -inform PEM -in "$src" -noout 2>/dev/null; then\n'
            + '  cat "$src" > "$out" || exit 13\n'
            + 'elif ! openssl x509 -inform DER -in "$src" -out "$out" 2>/dev/null; then\n'
            + '  exit 11\n'
            + 'fi\n'
            + 'openssl x509 -in "$out" -noout -checkend 0 >/dev/null 2>&1 || exit 12\n'

        run(["sh", "-c", script, "corium-ca", source, staged], (exitCode, stdout, stderr) => {
            switch (exitCode) {
            case 0:
                callback(true, "", staged, storageDir + "/certs/" + hex + ".pem")
                return
            case 10:
                callback(false, "Can't read the certificate file " + source + ".", "", "")
                return
            case 11:
                callback(false, "That file isn't a PEM or DER certificate. If you have an eduroam "
                         + "CAT installer, the CA certificate is embedded in it.", "", "")
                return
            case 12:
                callback(false, "The CA certificate has expired. Get the current one from your "
                         + "institution (e.g. cat.eduroam.org).", "", "")
                return
            case 14:
                callback(false, "openssl is needed to check the certificate but isn't installed.", "", "")
                return
            default:
                callback(false, "Could not prepare the certificate. " + stderr.trim(), "", "")
            }
        })
    }

    function enterpriseSettings(config, caCert) {
        const [eap, phase2] = {
            "peap-mschapv2": ["PEAP", "MSCHAPV2"],
            "ttls-pap": ["TTLS", "Tunneled-PAP"],
            "ttls-mschapv2": ["TTLS", "Tunneled-MSCHAPv2"]
        }[config.method]
        const prefix = "EAP-" + eap + "-"

        const username = config.username.trim()
        const outerIdentity = config.anonymousIdentity.trim() !== ""
            ? config.anonymousIdentity.trim()
            : defaultAnonymousIdentity(username)

        const lines = [
            "# Written by corium",
            "[Security]",
            "EAP-Method=" + eap,
            "EAP-Identity=" + escapeSetting(outerIdentity)
        ]
        if (caCert !== "")
            lines.push(prefix + "CACert=" + caCert)
        if (config.caMode !== "none" && config.domain.trim() !== "")
            lines.push(prefix + "ServerDomainMask=" + escapeSetting(config.domain.trim()))
        lines.push(
            prefix + "Phase2-Method=" + phase2,
            prefix + "Phase2-Identity=" + escapeSetting(username),
            prefix + "Phase2-Password=" + escapeSetting(config.password),
            "",
            "[Settings]",
            "AutoConnect=true",
            ""
        )
        return lines.join("\n")
    }

    function defaultAnonymousIdentity(username) {
        const at = username.indexOf("@")
        return at >= 0 ? "anonymous" + username.substring(at) : username
    }

    // iwd's settings parser unescapes \\, \s and \t in string values.
    function escapeSetting(text) {
        return text.replace(/\\/g, "\\\\").replace(/ /g, "\\s").replace(/\t/g, "\\t")
    }

    // The network object path ends in <hex-encoded SSID>_<type>.
    function ssidHex(network) {
        const segment = network.path.substring(network.path.lastIndexOf("/") + 1)
        return segment.substring(0, segment.lastIndexOf("_"))
    }

    // Mirrors iwd's storage naming: plain SSIDs are used as-is, others hex-encoded.
    function storageFileName(network, extension) {
        const base = /^[A-Za-z0-9 _-]+$/.test(network.name) ? network.name : "=" + ssidHex(network)
        return base + "." + extension
    }

    function connectAfterProvisioning(network, attempt, callback) {
        connectNetwork(network, (ok, message, code) => {
            if (!ok && code === "NotConfigured" && attempt < 4) {
                delay(1000, () => connectAfterProvisioning(network, attempt + 1, callback))
                return
            }
            callback(ok, message, code)
        })
    }

    function pkexecFailureMessage(exitCode, stderr) {
        if (/no authentication agent/i.test(stderr))
            return "No polkit authentication agent is running, so administrator access can't be "
                   + "requested. Start one (e.g. hyprpolkitagent) and try again."
        if (exitCode === 126)
            return "Authentication was cancelled."
        if (exitCode === 127)
            return "Authentication failed."
        if (exitCode === -2)
            return "Timed out waiting for authentication."
        return "Could not save the network configuration. " + stderr.trim()
    }

    // ------------------------------------------------------------------
    // D-Bus and process helpers
    // ------------------------------------------------------------------

    function describeError(code, raw) {
        switch (code) {
        case "Failed": return "Connection failed."
        case "NotConfigured": return "This network isn't configured yet."
        case "NoAgent": return "A password is required."
        case "Aborted": return "The operation was cancelled."
        case "InProgress": return "Already connecting."
        case "Busy": return "The device is busy. Try again in a moment."
        case "NotSupported": return "iwd doesn't support this network."
        case "NotAvailable": return "The network is not available."
        case "InvalidFormat": return "Invalid password format."
        case "NotConnected": return "Not connected."
        case "UnknownObject": return "The network is no longer in range."
        case "Timeout": return "Timed out waiting for iwd."
        }
        return raw !== "" ? raw : "Unknown error."
    }

    function call(path, iface, method, args, timeoutSeconds, callback) {
        run(["gdbus", "call", "--system", "--dest", service, "--object-path", path,
             "--timeout", String(timeoutSeconds), "--method", iface + "." + method, ...args],
            (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    callback(true, "", "")
                    return
                }
                const match = /GDBus\.Error:([\w.]+):\s*(.*)/.exec(stderr)
                let code = match ? match[1].substring(match[1].lastIndexOf(".") + 1) : ""
                if (code === "" && /timeout/i.test(stderr))
                    code = "Timeout"
                if (code === "UnknownMethod" || code === "UnknownInterface" || code === "NotFound")
                    code = "UnknownObject"
                callback(false, describeError(code, match ? match[2] : stderr.trim()), code)
            },
            { timeout: timeoutSeconds + 5 })
    }

    function setProperty(path, iface, name, boolValue, callback) {
        call(path, "org.freedesktop.DBus.Properties", "Set",
             ["'" + iface + "'", "'" + name + "'", "<" + boolValue + ">"], 15, callback)
    }

    // options: { input: string written to stdin, timeout: seconds }
    function run(command, callback, options) {
        const operation = commandComponent.createObject(root, {
            command: command,
            callback: callback,
            input: options?.input ?? "",
            hasInput: options?.input !== undefined,
            timeoutSeconds: options?.timeout ?? 30
        })
        operation.start()
    }

    function delay(milliseconds, action) {
        delayComponent.createObject(root, { interval: milliseconds, action: action })
    }

    Component {
        id: commandComponent

        Process {
            id: operation

            property var callback
            property string input
            property bool hasInput: false
            property int timeoutSeconds: 30
            property bool finished: false

            property Timer timeout: Timer {
                interval: operation.timeoutSeconds * 1000

                onTriggered: {
                    operation.running = false
                    operation.finish(-2, "", "Timed out")
                }
            }

            function start() {
                running = true
                timeout.start()
            }

            function finish(exitCode, stdout, stderr) {
                if (finished)
                    return
                finished = true
                timeout.stop()
                callback(exitCode, stdout, stderr)
                operation.destroy()
            }

            stdinEnabled: hasInput

            stdout: StdioCollector {
                id: stdoutCollector
            }

            stderr: StdioCollector {
                id: stderrCollector
            }

            onStarted: {
                if (hasInput) {
                    write(input)
                    stdinEnabled = false
                }
            }

            onExited: function(exitCode, exitStatus) {
                operation.finish(exitCode, stdoutCollector.text, stderrCollector.text)
            }
        }
    }

    Component {
        id: delayComponent

        Timer {
            id: delayTimer

            property var action

            running: true

            onTriggered: {
                action()
                delayTimer.destroy()
            }
        }
    }

    // ------------------------------------------------------------------
    // Live updates
    // ------------------------------------------------------------------

    Process {
        id: monitor

        command: ["gdbus", "monitor", "--system", "--dest", root.service]
        running: true

        stdout: SplitParser {
            onRead: refreshDebounce.restart()
        }

        onExited: monitorRestart.start()
    }

    Timer {
        id: monitorRestart

        interval: 3000

        onTriggered: {
            monitor.running = true
            root.refresh()
        }
    }

    Timer {
        id: refreshDebounce

        interval: 250

        onTriggered: root.refresh()
    }

    // Signal strength changes aren't signalled over D-Bus, so poll occasionally.
    Timer {
        interval: 30000
        running: true
        repeat: true

        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
