# System integration

Everything outside this repo the bar relies on. Use this when something
silently stops working after a system update or on a new machine.

## Programs called

| Program | Package (Arch) | Called from | What breaks without it |
| --- | --- | --- | --- |
| `quickshell` | quickshell | — | everything |
| Hyprland (via `Quickshell.Hyprland`; `hyprctl` only for debugging) | hyprland | Workspaces, OpenNotebooks | workspaces, notebook tabs |
| `date` | coreutils | widgets/Time.qml | bar clock |
| `cat`, `sh`, `test`, `mkdir`, `cp`, `find`, `rm`, `xargs`, `tr` | coreutils / findutils | various | lots |
| `busctl` | systemd | Iwd | Wi-Fi state |
| `gdbus` | glib2 | Iwd | Wi-Fi actions and live updates |
| `iwctl` (and `iwd` running) | iwd | Iwd | connecting with a new password |
| `rfkill` | util-linux | Iwd, Rfkill | turning Wi-Fi on when soft-blocked, airplane mode |
| `ip` | iproute2 | Iwd | Wi-Fi connection details (addresses, gateway) |
| `resolvectl` | systemd | Iwd | Wi-Fi connection details (DNS) |
| BlueZ (via `Quickshell.Bluetooth`; `bluetooth.service` running) | bluez | BluetoothPage | Bluetooth tab |
| `pkexec` + a polkit agent (e.g. `hyprpolkitagent`) | polkit | Iwd | saving 802.1X networks |
| `openssl` | openssl | Iwd | 802.1X with a CA certificate file |
| `brightnessctl` | brightnessctl | Brightness | brightness |
| PipeWire (via `Quickshell.Services.Pipewire`) | pipewire | Audio | audio |
| `pw-play` | pipewire | Timers | timer sound |
| `notify-send` + a notification daemon | libnotify | Timers | timer notifications |
| UPower (via `Quickshell.Services.UPower`) | upower | Battery | battery |
| power-profiles-daemon | power-profiles-daemon | Battery | power profile buttons |
| `systemctl`, `journalctl` | systemd | ServicesPage | services tab |
| `ps`, `kill` | procps-ng, util-linux | ProcessesPage | processes tab |
| `xournalpp`, `xournalpp-thumbnailer` | xournalpp | Xournalpp | notebooks |
| `pdftoppm`, `pdfinfo` | poppler | Xournalpp | PDF thumbnails / page counts |
| `gzip`, `xmllint` | gzip, libxml2 | Xournalpp | `.xopp` page counts |
| `pkill` + a running `wvkbd-deskintl` | procps-ng, wvkbd | OnScreenKeyboardToggle | OSK toggle |
| `screenshot` | personal script, `~/.local/bin/scripts/screenshot` | ScreenshotTool | screenshot button |
| `corium-calendar` | built from `helpers/` | CalendarEvents | calendar events |
| Akonadi + KOrganizer | akonadi, korganizer | corium-calendar | calendar events |
| A Nerd Font | e.g. ttf-nerd-fonts-symbols | everywhere | icons show as boxes |

Desktop entries, tray items (StatusNotifierItem), and Hyprland
workspace data come from Quickshell's built-in integrations.

## Files read

| Path | By | Why |
| --- | --- | --- |
| `~/Notes/Notebooks/**` | notebook components | notebooks, `notebook.json`, volumes |
| `~/.local/share/quickshell/corium/notebook-templates/*.xopp` | Xournalpp | global templates (`default.xopp` is the fallback) |
| `/proc/stat`, `/proc/meminfo` | SystemStats | CPU / memory / swap |
| `/proc/<pid>/stat`, `/proc/<pid>/cmdline` | ProcessesPage | process list |
| `~/.config/systemd/user/*.service` | ServicesPage | "My services" grouping |
| `~/.config/korganizerrc` | corium-calendar | which calendars are ticked |
| `/etc/ssl/certs/ca-certificates.crt` | Iwd | system CA bundle for 802.1X |
| `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga` | Timers | alarm sound |

## Files written

| Path | By |
| --- | --- |
| `~/.local/state/quickshell/by-shell/<hash>/launcher.json` | LauncherState |
| `~/.local/state/quickshell/by-shell/<hash>/timers.json` | Timers |
| `~/.local/state/quickshell/by-shell/<hash>/stopwatch.json` | Stopwatch |
| `~/.local/state/quickshell/by-shell/<hash>/airplane.json` | Rfkill (radios to turn back on after airplane mode) |
| `~/.cache/quickshell/corium/notebook-thumbnails/*.png` | Xournalpp |
| `~/.cache/quickshell/corium/ca-<ssidhex>.pem` | Iwd (staging) |
| `/var/lib/iwd/<ssid>.8021x`, `/var/lib/iwd/certs/<ssidhex>.pem` | Iwd via pkexec |
| New `NN_Untitled.xopp` files in notebook folders | Xournalpp |

## Hyprland config coupling

These live in `~/.config/hypr/hyprland.lua`, not here, but the bar depends on
them:

- **Autostart:** `hl.exec_cmd("quickshell -c corium")` on `hyprland.start`.
- **Notebook workspaces:** the `window.open` hook that moves each Xournal++
  window to `name:doc:xournal-<pid>`. Without it, the open-notebooks tabs stay
  empty. See [notebooks.md](notebooks.md#open-notebook-tabs).
- **Blur rule for the `launcher` layer namespace.** This was for the old
  `LauncherWindow.qml` (since deleted). The current popups (`OrganicPopUp`) don't set a
  namespace, so the rule doesn't match anything now.

The bar also sends Hyprland dispatches in the Lua-config syntax
(`hl.dsp.focus({ workspace = N })`,
`hl.dsp.window.close({ window = "address:0x…" })`).

## Hardcoded assumptions

- Notebook root `~/Notes/Notebooks` (`widgets/NotebookLauncher.qml`).
- Workspaces 1–5 (`widgets/Workspaces.qml`).
- Audio outputs with "DisplayPort" in their description are hidden
  (`widgets/Audio.qml`).
- Calendar weeks start on Monday via `en_GB` locale (`widgets/Clock.qml`).
- 100 clock ticks/s and 4 KiB pages (`widgets/sysmon/ProcessesPage.qml`).
- Bar height 48 px in several files (see [architecture.md](architecture.md#the-magic-number-48)).
- `.qmlls.ini` has a machine-specific `buildDir` under
  `/run/user/1000/quickshell/vfs/<hash>`; it's for the language server only.
