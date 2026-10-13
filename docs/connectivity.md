# Connectivity: Wi-Fi, Bluetooth, airplane mode

One bar button, [`widgets/Connectivity.qml`](../widgets/Connectivity.qml),
with two tabs in its popup:

| Part | Logic | UI |
| --- | --- | --- |
| Wi-Fi | [`services/Iwd.qml`](../services/Iwd.qml) | [`widgets/connectivity/WifiPage.qml`](../widgets/connectivity/WifiPage.qml) |
| Bluetooth | Quickshell's `Quickshell.Bluetooth` (BlueZ) | [`widgets/connectivity/BluetoothPage.qml`](../widgets/connectivity/BluetoothPage.qml) |
| Airplane mode | [`services/Rfkill.qml`](../services/Rfkill.qml) | its tile in `Connectivity.qml` |

## The bar button and popup

**Bar:** the Wi-Fi icon (signal strength; pulses while connecting) and the
Bluetooth icon side by side. Bluetooth is white with a "connected" glyph when
a device is connected, light grey when on, grey with a crossed-out glyph when
off or when BlueZ isn't running. In airplane mode both are replaced by an
airplane.

**Popup** (400 px, keyboard focus for the password fields):

1. Three **quick toggle tiles** (`QuickToggle`, inline in
   `Connectivity.qml`): Wi-Fi, Bluetooth, Airplane. Each shows a glyph, a
   name and a short status (network name, device name or count, On/Off) and
   is filled with the accent colour while on; tap to switch. The glyph pulses
   while switching, and a tile is dimmed and inert when there's nothing to
   switch (no iwd adapter, no BlueZ, no rfkill radios). The Wi-Fi and
   Bluetooth tiles call the pages' `togglePower(onFailure)`; on failure the
   popup switches to that tab, where the error is shown. Under the tiles: a
   warning if a hardware switch is blocking the radios, or rfkill's error.
2. Tabs (`TabSwitcher`): **Wi-Fi** / **Bluetooth**, the latter with a count of
   connected devices. The selected tab (`page`) is kept between openings.
3. The page, headed by its status line and its scan button (the power
   switch is the tile). Each one takes `active` (`popupVisible && visible`), and its
   `reset()` is called whenever the popup opens (back to the list).

Each page owns its `statusIcon`; the bar reads it from there
(`wifiPage.statusIcon`, `bluetoothPage.statusIcon`) so the bar and the page
header can't disagree.

---

## Wi-Fi (iwd)

There is no Quickshell API for iwd, and NetworkManager isn't used on this
machine, so the service drives **iwd's D-Bus API** with command-line tools:

| Tool | Used for |
| --- | --- |
| `busctl --json=short` | Reading state (`GetManagedObjects`, `GetOrderedNetworks`) |
| `gdbus call --system` | Method calls (`Connect`, `Disconnect`, `Scan`, `Forget`, setting `Powered`) |
| `gdbus monitor --system --dest net.connman.iwd` | Live updates |
| `iwctl` | Connecting with a new passphrase (needs an agent; see below) |
| `rfkill unblock wlan` | Turning Wi-Fi on when soft-blocked |
| `pkexec` | Writing 802.1X config files into root-owned `/var/lib/iwd` |
| `openssl` | Checking / converting CA certificates |
| `ip -j`, `resolvectl dns` | Addresses, gateway and DNS for the connection details |

### State

`refresh()`:

1. `GetManagedObjects` on `/` → all iwd objects with their properties.
2. Picks the **device** (prefers one with a `Station` interface), its
   **adapter** (looked up separately because iwd removes devices when the
   adapter is powered off), and the station.
3. `GetOrderedNetworks` on the station → signal strength per network (in
   100 × dBm).
4. Builds `networks`: `{ path, name, type, connected, knownPath, signal,
   strength }`, sorted connected-first, then by signal, then by name.
   `type` is `open | psk | 8021x | wep`; `strength` is 1–4 from thresholds
   −60 / −67 / −75 dBm.

Refreshes are serialized (`refreshing` / `refreshQueued`). They're triggered:

- 250 ms after any line from `gdbus monitor` (debounced),
- every 30 s, since signal-strength changes aren't signalled,
- when the monitor restarts (it's restarted 3 s after exiting, e.g. if iwd
  restarts).

Exposed state: `available` (iwd reachable), `powered` (adapter **and** device
on), `hasDevice`, `state` (`connected`, `connecting`, …), `scanning`,
`networks`, `connectedNetwork`, `deviceName`.

### Actions

All take `callback(ok, message, code)`, where `code` is the short iwd error
name (`Failed`, `NotConfigured`, `NoAgent`, …) and `message` is already
human-readable (`describeError`).

- `scan()`. Busy/InProgress errors are ignored.
- `setPowered(on, cb)`. Turning on: if the adapter is off, try
  `rfkill unblock wlan`, power the adapter on, wait a second for the device to
  reappear, power the device on, scan.
- `connectNetwork(network, cb)`: plain `Network.Connect`. Works for open and
  already-known networks.
- `connectWithPassphrase(network, pass, cb)`: iwd needs a registered *agent*
  to supply passwords, which would mean implementing a D-Bus service. Instead
  this shells out to `iwctl --dont-ask --passphrase <pass> station <dev>
  connect <ssid>`. Known networks are forgotten first, because a saved
  passphrase takes precedence over `--passphrase`.
  **Caveat:** the passphrase is briefly visible in the process list.
- `disconnect(cb)`, `forget(network, cb)`. Forgetting an 802.1X network also
  makes iwd delete its provisioning file.
- `connectionInfo(cb)`: details of the current connection, for the connected
  network's page. One `sh` runs `ip -j addr show dev <iface>`, `ip -j route
  show default dev <iface>` and `resolvectl dns <iface>` (IPv4 with prefix,
  global IPv6 addresses, gateway, DNS, MAC); then iwd's
  `StationDiagnostic.GetDiagnostics` adds frequency, channel, security, the
  Wi-Fi standard (`RxMode` such as `802.11ax`, shown as "Wi-Fi 6") and
  link speeds (iwd reports them in 100 kbit/s). Missing fields are left out.

All D-Bus calls go through `call()`, which runs with a timeout and turns
`GDBus.Error:net.connman.iwd.Foo: text` into `code = "Foo"`.

### Enterprise / eduroam (802.1X)

iwd can't connect to an 802.1X network until a provisioning file exists in
`/var/lib/iwd/<name>.8021x`, and that directory is root-only.
`provisionEnterprise(network, config, cb, progress)` does it:

1. **Validate** (`validateEnterprise`): no newlines in any field, username
   and password present, eduroam usernames must contain `@realm`, a CA path if
   "file" was chosen, and a server domain if the *system* CA bundle is used.
   Without the domain, any server with a publicly-trusted certificate could
   collect the password, so that one is mandatory.
2. **CA certificate** (`prepareCaCertificate`):
   - `system` → `/etc/ssl/certs/ca-certificates.crt`.
   - `file` → the user's file is checked with `openssl`, converted to PEM if
     it's DER, rejected if expired, and staged in
     `~/.cache/quickshell/corium/ca-<ssidhex>.pem`. It has to be *installed*
     into `/var/lib/iwd/certs/` because iwd runs with `ProtectHome=yes` and
     can't read home.
   - `none` → no validation (the UI warns).
3. **Write** (one `pkexec /bin/sh -c …`): optionally installs the cert, then
   writes the settings file atomically (temp file + `mv`). The file contents,
   including the password, go through **stdin**, never the command line.
   Needs a running polkit agent (e.g. `hyprpolkitagent`); the error message
   says so if there isn't one.
4. **Connect**: wait 1 s for iwd to notice the file (inotify), then
   `Connect`, retrying up to 4 times on `NotConfigured`.

Generated file (`enterpriseSettings`):

```ini
# Written by corium
[Security]
EAP-Method=PEAP|TTLS
EAP-Identity=<anonymous identity>        # default: anonymous@<realm>
EAP-<m>-CACert=<path>                     # unless caMode == none
EAP-<m>-ServerDomainMask=<domain>         # if given
EAP-<m>-Phase2-Method=MSCHAPV2|Tunneled-PAP|Tunneled-MSCHAPv2
EAP-<m>-Phase2-Identity=<username>
EAP-<m>-Phase2-Password=<password>

[Settings]
AutoConnect=true
```

Supported combinations: PEAP/MSCHAPv2, TTLS/PAP, TTLS/MSCHAPv2. Values are
escaped the way iwd's parser expects (`\\`, `\s`, `\t`).

File name (`storageFileName`) mirrors iwd: the SSID as-is if it's only
`[A-Za-z0-9 _-]`, otherwise `=<hex SSID>`. The hex SSID is taken from the end
of the network's D-Bus object path.

### UI ([`widgets/connectivity/WifiPage.qml`](../widgets/connectivity/WifiPage.qml))

Two pages inside the tab, `list` and `details`.

- **Header**: status text and rescan button. Power is the Wi-Fi tile.
- **List**: tap a network →
  - connected or WEP → details;
  - known or open → connect immediately; if that fails with an error meaning
    "needs credentials", open details with the form;
  - otherwise → details with the password / enterprise form.
- **Details**: security type, saved/connected, dBm; Connect/Disconnect,
  Forget (enterprise asks for confirmation since it deletes the stored
  credentials), "Change password…" / "Edit credentials…". For the connected
  network, a card with `Iwd.connectionInfo()`: IP, gateway, DNS, band and
  channel, standard, security, link speed, MAC. It is fetched on opening the
  page and again 1.5 s after any `Iwd.state` change (DHCP needs a moment).
- **Forms**: WPA-Personal password, or the enterprise form (username,
  password, method, CA mode, CA path, server domain, anonymous identity, with
  the default shown as placeholder).
- All actions go through `perform(text, action, onSuccess, onFailure)`, which
  sets `busy`/`busyText` and shows the error on failure.
- While the tab is shown and Wi-Fi is on, it rescans on showing and every
  15 s. On opening the popup, it goes back to the list unless an action is
  still running.
- The selected network is kept as a snapshot so the details page doesn't
  vanish if the network drops out of a scan.
- The bar icon pulses while `state === "connecting"`.

---

## Bluetooth

[`widgets/connectivity/BluetoothPage.qml`](../widgets/connectivity/BluetoothPage.qml)
uses Quickshell's built-in `Quickshell.Bluetooth` module, which talks to
**BlueZ** (`bluetoothd`) over D-Bus. No service of our own is needed:
`Bluetooth.defaultAdapter` and its `devices` are already live objects.

**Requires** the `bluez` package and `bluetooth.service` running. Without it
`defaultAdapter` is null, the tab says so, and Quickshell logs
`Failed to create DBusObjectManagerInterface for "org.bluez"` on every
reload.

**Start BlueZ before Quickshell.** Quickshell's Bluetooth backend connects
to BlueZ once, when the process starts, and doesn't retry; hot reloads don't
redo it. If `bluetooth.service` was started (or installed) after Quickshell,
the tab keeps saying it can't reach BlueZ until Quickshell is restarted
(`quickshell kill -c corium && quickshell -c corium -d`).

### State

- `adapter.enabled` is BlueZ's `Powered`; `adapter.state` adds
  `Enabling`/`Disabling` and `Blocked` (rfkill).
- `pairedDevices`: connected first, then by name. `nearbyDevices`: unpaired
  devices that have a real name (`deviceName !== ""`); nameless ones are
  mostly beacons you can't pair with.
- Battery (`batteryAvailable`, `battery` 0–1) comes from BlueZ's `Battery1`
  and is shown next to "Connected" when the device reports it.
- Device icons map BlueZ's freedesktop icon names (`audio-headset`,
  `input-mouse`, `phone`, …) to Nerd Font glyphs in `deviceIcon()`.

### Discovery

The adapter looks for devices (`adapter.discovering`) while the list is shown
(`active && page === "list"` and the adapter's state is `Enabled`; `enabled`
turns on before the radio is ready, and starting discovery then fails with
"Resource Not Ready") and stops when you leave the tab,
open a device's page or close the popup. Discovery costs power and slows down
other Bluetooth traffic (audio), so it never stays on in the background. The
radar button shows and toggles it by hand.

### Actions

Quickshell's device methods return nothing and report no errors, so the page
follows the device it acted on (`pending`, `pendingAction`) through its
property changes:

- **Tap a paired device:** connect or disconnect. A connect that ends in
  `Disconnected` instead of `Connected` shows "Couldn't connect…".
- **Tap a nearby device:** `pair()`; once `paired` turns on, set
  `trusted = true` (so it can reconnect by itself later) and `connect()`.
  If `pairing` turns off without `paired`, it waits 1 s (the two signals can
  arrive in either order) and then shows "Couldn't pair…".
- **Device page** (chevron on a paired device): Connect/Disconnect, Forget
  (`forget()` = BlueZ `RemoveDevice`), and a "Connect automatically" toggle
  bound to `trusted`.
- **Power** (the Bluetooth tile): sets `adapter.enabled`. If the adapter is rfkill-blocked
  (e.g. after airplane mode), it first runs `Rfkill.unblock("bluetooth")` and
  enables the adapter 500 ms later.

**Pairing limitation:** Quickshell doesn't register a BlueZ *agent* (the
D-Bus service that shows PINs and confirmation prompts), so BlueZ pairs as
"no input, no output" (Just Works). That works for headphones, speakers,
mice, controllers and phones (the phone asks to confirm), but not for devices
that make you type or compare a PIN, typically keyboards. Pair those once with
`bluetoothctl` (from `bluez-utils`); after that they connect from here.

---

## Airplane mode (rfkill)

[`services/Rfkill.qml`](../services/Rfkill.qml).

- State: `rfkill -J`, re-read 100 ms after each line of `rfkill event` (which
  prints every device once on start, then one line per change). The monitor is
  restarted 3 s after it exits.
- `airplaneMode` is **derived**, not stored: it is true when every `wlan` and
  `bluetooth` rfkill device is blocked (soft or hard). Turning Wi-Fi or
  Bluetooth back on unblocks that radio and so ends airplane mode, as on a
  phone.
- `setAirplaneMode(true, cb)` first remembers which radios are on
  (`radiosBeforeAirplane = { wlan: Iwd.powered, bluetooth: adapter.enabled }`,
  saved to `airplane.json` in the state dir so it survives restarts), then
  runs `rfkill block all` (this also covers wwan, NFC, etc. if present).
- `setAirplaneMode(false, cb)` unblocks **only the radios that were on**.
  iwd and BlueZ (`AutoEnable`, on by default) power a radio up the moment
  it's unblocked, so a plain `rfkill unblock all` would switch Bluetooth on
  even if it had been off. Radios that were off stay soft-blocked instead,
  which shows as "Off"; turning one on from its tile unblocks it.
  - Nothing was on → only Wi-Fi is unblocked, so you're connected again.
  - Nothing remembered (airplane mode came from a hardware key or
    `rfkill` directly) → `rfkill unblock all`.
- The memory is cleared whenever airplane mode ends, however it ends (e.g.
  turning Wi-Fi on from its tile while in airplane mode).
- `hardBlocked`: a hardware switch is off; the popup shows a warning since
  software can't override it.
- Needs write access to `/dev/rfkill`, which logind grants the active session
  (an ACL for your user); no root.
