# Wi-Fi (iwd)

Files: [`services/Iwd.qml`](../services/Iwd.qml) (logic) and
[`widgets/Wifi.qml`](../widgets/Wifi.qml) (UI).

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

## State

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

## Actions

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

All D-Bus calls go through `call()`, which runs with a timeout and turns
`GDBus.Error:net.connman.iwd.Foo: text` into `code = "Foo"`.

## Enterprise / eduroam (802.1X)

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

## UI ([`widgets/Wifi.qml`](../widgets/Wifi.qml))

Two pages inside the popup, `list` and `details`.

- **Header**: icon, status text, rescan button, power toggle.
- **List**: tap a network →
  - connected or WEP → details;
  - known or open → connect immediately; if that fails with an error meaning
    "needs credentials", open details with the form;
  - otherwise → details with the password / enterprise form.
- **Details**: security type, saved/connected, dBm; Connect/Disconnect,
  Forget (enterprise asks for confirmation since it deletes the stored
  credentials), "Change password…" / "Edit credentials…".
- **Forms**: WPA-Personal password, or the enterprise form (username,
  password, method, CA mode, CA path, server domain, anonymous identity, with
  the default shown as placeholder).
- All actions go through `perform(text, action, onSuccess, onFailure)`, which
  sets `busy`/`busyText` and shows the error on failure.
- While the popup is open and Wi-Fi is on, it rescans every 15 s. On opening,
  it goes back to the list unless an action is still running.
- The selected network is kept as a snapshot so the details page doesn't
  vanish if the network drops out of a scan.
- The bar icon pulses while `state === "connecting"`.
