# Architecture

## Quickshell in two paragraphs

Quickshell is a Qt/QML shell toolkit for Wayland. You point it at a folder
(`quickshell -c corium` looks in `~/.config/quickshell/corium`) and it loads
`shell.qml`. Windows are `PanelWindow`s, which are wlr-layer-shell surfaces
(bars, overlays) rather than normal app windows. It watches the folder and
**hot-reloads** the whole config when a file is saved; errors show up in the
terminal Quickshell was started from (or its log).

The parts of Quickshell this config uses:

| Quickshell feature | Used for |
| --- | --- |
| `PanelWindow`, `Variants`, `Quickshell.screens` | The bar (one per screen) and every popup |
| `WlrLayershell` | Popup layer (`Top`) and keyboard focus mode |
| `Process`, `StdioCollector`, `SplitParser` | Running every external command |
| `Quickshell.execDetached` | Fire-and-forget commands (launching apps, `notify-send`, `brightnessctl set`, …) |
| `FileView` + `JsonAdapter` | Persisted state files and reading `notebook.json` |
| `Quickshell.statePath()` | Where state files go (`~/.local/state/quickshell/by-shell/<hash>/`) |
| `Quickshell.shellDir` | Finding `helpers/build/…` relative to the config |
| `ScriptModel` | Turning a JS array into a model that diffs nicely in `Repeater`s |
| `Quickshell.Hyprland` | Workspaces, `Hyprland.dispatch` |
| `Quickshell.Services.Pipewire` | Audio |
| `Quickshell.Services.UPower` | Battery and power profiles |
| `Quickshell.Services.SystemTray` | Tray icons |
| `DesktopEntries` | App launcher |

`shell.qml` starts with `//@ pragma UseQApplication`, which makes Quickshell use
a `QApplication` instead of a `QGuiApplication`, for the bits that rely on Qt
Widgets (such as the tray's native menus).

## Object tree

```
shell.qml (Scope)
└─ widgets/Bar.qml (Scope)
   └─ Variants over Quickshell.screens
      └─ PanelWindow "bar"  — anchored top/left/right, 48 px tall, black
         └─ RowLayout
            ├─ NotebookLauncher ─┐ (BarPopupButton, popup on the left, full height)
            ├─ AppLauncher      ─┘ (BarPopupButton, popup on the left, full height)
            ├─ Workspaces
            ├─ OpenNotebooks        (fills remaining width)
            ├─ ScreenshotTool, OnScreenKeyboardToggle
            ├─ Wifi, Brightness, Audio, Battery, SysMonitor   (BarPopupButtons)
            ├─ SysTray
            └─ Clock                (BarPopupButton)
```

Each `BarPopupButton` owns an `OrganicPopUp`, which is its *own*
`PanelWindow`. So every popup-capable widget has a (normally invisible)
full-screen layer surface. Order in the bar is just the order in
[`Bar.qml`](../widgets/Bar.qml); rearrange items there.

## The popup pattern

Nearly every interactive widget is built the same way. Understanding these two
files explains most of the UI.

### [`widgets/utils/BarPopupButton.qml`](../widgets/utils/BarPopupButton.qml)

An `Item` that is the bar slot. It:

- draws a `#222222` highlight behind itself while its popup is open,
- has a full-size `MouseArea` that sets `popupVisible = true` on click,
- contains an `OrganicPopUp` whose `visible` follows `popupVisible` and which
  sets it back to `false` on `dismissed`. The popup's `screen` is bound to the
  screen of the bar window the button sits in (via the `QsWindow.window`
  attached property), so with several monitors each popup opens on its own
  bar's screen.

To close the popup from inside its content (e.g. after an action), set
`root.popupVisible = false` on the `BarPopupButton`. It has no `dismissed()`
signal of its own; that's on the inner `OrganicPopUp`.

Properties a widget sets:

| Property | Meaning |
| --- | --- |
| `popup` | The popup's content (alias to `OrganicPopUp.content`). Give it an `implicitWidth`/`implicitHeight`; the popup sizes itself from those. |
| `popupVisible` | Open/closed. Widgets watch `onPopupVisibleChanged` to refresh data when opened. |
| `leftSide` | Popup hangs off the left edge of the screen instead of the right. |
| `fullHeight` | Popup background goes all the way to the bottom of the screen. |
| `keyboardFocus` | Let text fields in the popup take keyboard focus (needed for search/name fields, and for the on-screen keyboard to type into them). |

Whatever else you put inside a `BarPopupButton` (icons, text) is what shows in
the bar. A widget can add its own `MouseArea` on top to handle wheel events or
extra click behaviour (Brightness does).

### [`widgets/utils/OrganicPopUp.qml`](../widgets/utils/OrganicPopUp.qml)

A `PanelWindow` anchored to all four edges on the `Top` layer with
`ExclusionMode.Ignore`, fully transparent. That gives it the whole screen, so:

- a `MouseArea` behind everything emits `dismissed()` on any click outside the
  panel (tap-outside-to-close);
- a second `MouseArea` the size of the panel swallows clicks inside it;
- a `Shape` draws the black panel. Its top edge sits at `y: 48` (bar bottom)
  with a **concave** corner where it meets the bar and **convex** rounded
  bottom corners, so it looks like it grows out of the bar. `radius` (28)
  controls both. `leftSide` mirrors the shape with a `Scale { xScale: -1 }`.
  With `fullHeight`, the shape runs to the screen bottom and the bottom corner
  next to the screen edge is squared off.
- the content goes into a `Column` (`default property alias content`) placed
  at the panel's position.

Keyboard focus: `WlrKeyboardFocus.OnDemand` if `keyboardFocus` is set,
otherwise `None`.

### The magic number 48

The bar height (48 px) is hardcoded in many places rather than shared:
`Bar.qml` (`implicitHeight`), `BarPopupButton.qml`, `OrganicPopUp.qml`
(`y: 48`, `height - 48`), and the full-height popups
(`screen.height - 48` in NotebookLauncher, AppLauncher, SysMonitor). Change
all of them together if you change the bar height (`grep -rn 48 widgets`).

## Services

`services/` holds `pragma Singleton` QML files registered in
[`services/qmldir`](../services/qmldir). Widgets import them with
`import "../services"` (or `"../../services"` from subfolders) and use them by
name (`Iwd.networks`, `Timers.start(...)`).

A thing goes into a service when it has state that should outlive a popup,
is shared by several widgets, or wraps a non-trivial system API. Simple
one-widget polling (brightness, the process list) stays in the widget.

**When adding a service**, add a line to `services/qmldir` too. Quickshell
also detects `pragma Singleton` on its own (that's how
[`widgets/Time.qml`](../widgets/Time.qml) works without a qmldir), but keep
the qmldir in sync so the language server and imports stay predictable.

See [services.md](services.md) for each one.

## Recurring patterns

### Running commands

There is no shared "run" helper; each place that runs commands does it one of
three ways:

1. **A declared `Process`** with a fixed or reassigned `command`, started by
   setting `running = true`, output read with
   `stdout: StdioCollector { onStreamFinished: … }`. Used for periodic polls
   (SystemStats, Brightness, ProcessesPage, ServicesPage, Time).
2. **A dynamically created `Process` per call**, wrapped in a
   `run(command, callback)` function that creates it from a `Component`, calls
   `callback(exitCode, stdout, stderr)` and destroys itself. `Iwd.qml` and
   `Xournalpp.qml` each have their own copy; Iwd's also supports stdin input
   and a timeout. Use this when several calls may be in flight at once.
3. **`Quickshell.execDetached([...])`** when the result doesn't matter.

Shell snippets are run as `["sh", "-c", script, "$0", "$1", …]` with values
passed as positional arguments rather than spliced into the script. Keep doing
that; it's what keeps file names with spaces/quotes from breaking things.

### Long-running children

Two services keep a child process alive and react to its output line by line
with `SplitParser`:

- `Iwd`: `gdbus monitor --system --dest net.connman.iwd` — any line → debounced refresh.
- `CalendarEvents`: `corium-calendar serve` — JSON-lines protocol.

Both restart the child on a timer if it exits.

### Persisted state

State that must survive reloads and restarts is stored as JSON under
`Quickshell.statePath(...)`, i.e. `~/.local/state/quickshell/by-shell/<hash>/`
where the hash is derived from the config path (moving the repo gives you
fresh state).

| File | Owner | How it's written |
| --- | --- | --- |
| `launcher.json` | `LauncherState` | `FileView` + `JsonAdapter`, `onAdapterUpdated: writeAdapter()` |
| `timers.json` | `Timers` | same |
| `stopwatch.json` | `Stopwatch` | plain `setText(JSON.stringify(...))`, read synchronously at startup (the comment in the file explains why `JsonAdapter` wasn't reliable there) |

Timers and the stopwatch store **wall-clock timestamps**, not tick counts, so
they keep running correctly through reloads and while Quickshell is not running.

Caches go to `~/.cache/quickshell/corium/` (notebook thumbnails, staged CA
certificates).

### Refresh only while visible

Expensive pages take an `active` property (`popupVisible && visible`) and only
run their timers while it's true: ProcessesPage, ServicesPage, StopwatchPage.
The clock's "now" timer and the Wi-Fi rescans also only run while the popup is
open.

### Touch-first UI

The laptop is mostly used with a finger or pen, so:

- controls are ≥ 44 px tall; whole rows are tap targets;
- sliders are `FillSlider` ([`widgets/utils/FillSlider.qml`](../widgets/utils/FillSlider.qml)):
  the whole track is the handle, so tap or drag anywhere;
- lists freeze or stop refreshing while you're interacting (ProcessesPage
  freezes while a row is expanded so the "Kill" button doesn't move);
- swipe and wheel both change month in the calendar.

### Visual style

There's no theme file; colours are literals. The palette in use:

| Role | Colour |
| --- | --- |
| Bar and popup background | `black` |
| Cards / fields | `#1c1c1c`, `#262626`, `#292929`, `#303030` |
| Pressed | `#404040` / `#505050` |
| Divider | `#404040` |
| Primary text / secondary / tertiary | `white` / `#aaaaaa` / `#777777` |
| Accent (selection, sliders, focus borders, today) | `#80bfff` (pressed `#99ccff`), selected chip bg `#203040` |
| Warning | `#ffaa00` |
| Error / danger | `#ff5555`, `#ff7777`; danger button bg `#3a1a1a` |
| Success / running | `#77dd77` |
| Swap (system monitor) | `#c58aff` |

Icons are Nerd Font glyphs. Older files paste the glyph directly into the
string (invisible in some editors); newer ones use
`String.fromCodePoint(0xF….)`, which is easier to read and search for.
Look codepoints up at <https://www.nerdfonts.com/cheat-sheet>.

Small one-off controls (buttons, chips, toggles) are defined as inline
`component Foo: Rectangle { … }` at the bottom of the file that uses them,
not shared. Copy from a neighbouring file when you need one.
