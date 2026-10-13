# Development

## Running and reloading

```sh
quickshell -c corium            # from a terminal, to see logs
```

Normally Hyprland starts it at login. To work on it, kill that instance and
run it from a terminal so `console.log` / `console.warn` output and QML errors
are visible. Quickshell **hot-reloads on save**. A broken file usually leaves
the previous version running and prints the error.

Things that survive a reload: timers, stopwatch, launcher favourites/recents
(they're on disk). Things that don't: which popup tab was open, the calendar
helper process (it's restarted; this is how a rebuilt helper gets picked up).

Useful subcommands: `quickshell log -c corium` (logs of the running
instance), `quickshell kill -c corium`, `quickshell list`. Add `-v`/`-vv` for
Quickshell's internal logs.

### Editor setup

- `.qmlls.ini` points the QML language server at Quickshell's generated VFS
  dir (`/run/user/1000/quickshell/vfs/<hash>`) so imports resolve. The hash
  is per config path and matches the state directory hash. Quickshell
  appears to keep this file up to date when it starts. If completion breaks,
  compare it with what's in `/run/user/1000/quickshell/vfs/`.
- `.vscode/settings.json` enables `qt-qml.qmlls.useQmlImportPathEnvVar` and
  points the CMake extension at `helpers/`.

### The C++ helper

See [calendar.md](calendar.md#building). Build into `helpers/build`, run
`ctest`.

## Recipes

### Add a simple bar button (no popup)

Copy [`ScreenshotTool.qml`](../widgets/ScreenshotTool.qml): a 48×48 `Item`, a
round press highlight, a glyph at 50 % opacity, and `execDetached` on click.
Add it to the `RowLayout` in [`Bar.qml`](../widgets/Bar.qml).

### Add a bar item with a popup

```qml
import QtQuick
import "utils"
import "../services"

BarPopupButton {
    id: root
    implicitWidth: 60
    implicitHeight: 48
    // leftSide: true; fullHeight: true; keyboardFocus: true   as needed

    // What shows in the bar:
    Text { anchors.centerIn: parent; text: "…"; color: "white"; font.pixelSize: 18 }

    onPopupVisibleChanged: if (popupVisible) { /* refresh data */ }

    popup: Rectangle {
        implicitWidth: 400                         // the popup sizes itself from these
        implicitHeight: column.implicitHeight + 32
        color: "transparent"                       // the black shape is drawn behind

        Column { id: column; anchors.fill: parent; anchors.margins: 16; spacing: 14
            // content
        }
    }
}
```

[`Brightness.qml`](../widgets/Brightness.qml) is the simplest real example;
[`Battery.qml`](../widgets/Battery.qml) shows an inline helper component. Build
popup contents from the shared controls in `widgets/utils/` (`ActionButton`,
`Chip`, `InputField`, …; see
[architecture.md](architecture.md#shared-controls)). If the
popup is full-height, use `implicitHeight: screen.height - 48` and pass
`screen: bar.screen` from `Bar.qml` the way NotebookLauncher/SysMonitor do.

### Add a service

1. Create `services/Foo.qml` starting with `pragma Singleton`, root
   `Singleton { id: root … }`.
2. Add `singleton Foo 1.0 Foo.qml` to `services/qmldir`.
3. Use it from widgets after `import "../services"`.
4. If it needs to persist something, copy the `FileView` + `JsonAdapter` +
   `Quickshell.statePath("foo.json")` block from `Timers.qml` or
   `LauncherState.qml`. Store timestamps rather than counters if it's
   time-based.

### Run a command and use its output

One-shot with a fixed command: a `Process { command: […]; stdout:
StdioCollector { onStreamFinished: use(text) } }` and `running = true`.
Several calls in flight or a callback style: copy `run()` and its `Component`
from [`Iwd.qml`](../services/Iwd.qml) (that version supports stdin and
timeouts). Pass user-controlled values as separate argv entries or as
positional `$1…` args to `sh -c`, never by splicing them into the script.

### Add a popup tab / page

Clock and SysMonitor both use the same pattern: a `page` string property, a
`TabSwitcher` to change it, and pages with `visible: root.page === "…"`:

```qml
TabSwitcher {
    width: parent.width
    model: [{ value: "processes", label: "Processes" }, { value: "services", label: "Services" }]
    current: root.page
    onActivated: value => root.page = value
}
```

 Give expensive pages an `active` property
bound to `root.popupVisible && visible` and gate their timers on it.

## Known rough edges

Things that look odd on purpose, and things that are just leftovers. None of
these are fixed yet.

- **`OnScreenKeyboardToggle.keyboardVisible`** flips locally and isn't
  synced with wvkbd's real state. Nothing reads it.
- **`Xournalpp.qml` logs `Cannot read property 'finished' of null`** when
  the config reloads while thumbnail or page-count commands are still
  running: their QML objects are torn down by the reload before the process
  exits. Harmless, and only seen while editing.
- **Dead code:**
  - Large commented-out old versions at the bottom of `Audio.qml` and
    `AppLauncher.qml`, a commented `Clock` and `NotebookManager` test window in
    `Bar.qml`, and commented thumbnail code in `DirectoryPreview.qml`.
  - `BarPopupButton` imports `Quickshell.Services.Pipewire` and has an unused
    `wheel_acc` and empty hover handlers.
  - `shell.qml` imports `widgets/utils` but doesn't use it.
- **Colours are literals** everywhere, in the shared controls too; see the
  palette in [architecture.md](architecture.md#visual-style).

## Debugging tips

- **A widget shows nothing / stale data:** run the command it uses by hand
  (see [system-integration.md](system-integration.md#programs-called)). Most
  failures are a missing binary or changed output format.
- **Wi-Fi says "iwd is not running":** `busctl call net.connman.iwd /
  org.freedesktop.DBus.ObjectManager GetManagedObjects` must work for your
  user.
- **No calendar events:** is `helpers/build/calendar/corium-calendar`
  there? Does `corium-calendar list <from> <to>` print events? Are the
  calendars ticked in KOrganizer? Is Akonadi running (`akonadictl status`)?
- **Notebook tabs missing:** check the Hyprland `window.open` hook and that
  the workspace names start with `doc:` (`hyprctl workspaces`).
- **Thumbnails wrong:** delete `~/.cache/quickshell/corium/notebook-thumbnails/`.
- **Reset a feature's saved state:** delete its JSON in
  `~/.local/state/quickshell/by-shell/<hash>/`.
