# Bar widgets

Left to right, as laid out in [`widgets/Bar.qml`](../widgets/Bar.qml). For the
`BarPopupButton` / `OrganicPopUp` mechanics they share, see
[architecture.md](architecture.md#the-popup-pattern).

---

## Notebook launcher

[`widgets/NotebookLauncher.qml`](../widgets/NotebookLauncher.qml) — a
`BarPopupButton` (left side, full height, 450 px wide) whose popup is a
`NotebookManager` rooted at `~/Notes/Notebooks`. All the logic is in
`widgets/notebooks/` and `services/Xournalpp.qml`; see
[notebooks.md](notebooks.md).

To change the notebook folder, edit `basePath` here.

---

## App launcher

[`widgets/AppLauncher.qml`](../widgets/AppLauncher.qml) — left-side, full-height,
800 px popup with `keyboardFocus: true`.

- **Data:** Quickshell's `DesktopEntries`. Three `ScriptModel`s:
  favourites and recents (IDs from `LauncherState`, mapped through
  `DesktopEntries.byId`, unknown IDs dropped) and the filtered list of all
  apps.
- **Search:** case-insensitive substring match on name, generic name and
  comment. Apps with `Terminal=true` are always hidden. Sorted by name.
  While the search field has text, only "Results" is shown (favourites and
  recents are hidden). The field is cleared whenever the popup closes, and
  the list scrolls back to the top on every keystroke.
- **Launching:** `LauncherState.launchApplication(app)`, which records it in
  recents (max 12) and calls `app.execute()`.
- **Favourites:** the star on each tile in "All Applications" toggles
  `LauncherState.toggleFavorite`.
- Grid: 5 columns for favourites/recents (48 px icons), 6 for the full list
  (30 px icons). The three grids repeat the same delegate; change all three if
  you change one.

Launching an app also closes the popup (`root.popupVisible = false`).

The commented-out block at the bottom of the file is left over from an older
full-screen launcher (`LauncherWindow.qml`, since deleted).

---

## Workspaces

[`widgets/Workspaces.qml`](../widgets/Workspaces.qml) — always shows
workspaces **1–5** (a fixed `Repeater { model: 5 }`), whether they exist or
not. Looks each one up in `Hyprland.workspaces` to know if it's focused (grey
background) or occupied (lighter number).

Clicking dispatches `hl.dsp.focus({ workspace = N })`. That string is
Hyprland's Lua-config dispatcher syntax (this machine runs Hyprland with
`hyprland.lua`); if Hyprland's dispatch syntax changes, update it here and in
`OpenNotebooks.qml`.

---

## Open notebooks

[`widgets/OpenNotebooks.qml`](../widgets/OpenNotebooks.qml) — one tab per
Hyprland workspace whose name starts with `doc:`. Each Xournal++ window gets
its own such workspace thanks to a rule in the **Hyprland config**, not in this
repo (see [notebooks.md](notebooks.md#open-notebook-tabs)).

- Label: the title of the first window in the workspace, cut at the first
  `.` (so `Lecture3.xopp - Xournal++` → `Lecture3`).
- Tap: `workspace.activate()`.
- ✕ button: if that workspace is focused, first go back to
  `previous_per_monitor`; then close the window by address.

---

## Screenshot

[`widgets/ScreenshotTool.qml`](../widgets/ScreenshotTool.qml) — runs
`screenshot` (a personal script on `PATH`, `~/.local/bin/scripts/screenshot`,
not in this repo).

## On-screen keyboard

[`widgets/OnScreenKeyboardToggle.qml`](../widgets/OnScreenKeyboardToggle.qml) —
sends `SIGRTMIN` to `wvkbd-deskintl` (`pkill -RTMIN`), which makes wvkbd toggle
its visibility. It does **not** start wvkbd; something else must have it
running. The `keyboardVisible` property just flips locally and isn't used for
anything visible.

---

## Wi-Fi

[`widgets/Wifi.qml`](../widgets/Wifi.qml) — the UI for
[`services/Iwd.qml`](../services/Iwd.qml). Big enough to have its own page:
[wifi.md](wifi.md).

---

## Brightness

[`widgets/Brightness.qml`](../widgets/Brightness.qml) — everything through
`brightnessctl`.

- Reads `brightnessctl max` once and `brightnessctl get` every 2 s (and after
  every change). Polls are ignored while the slider is being dragged so it
  doesn't jump back.
- Popup: one `FillSlider`, 1–100 %. Changes are rate-limited to one
  `brightnessctl set N%` every 40 ms.
- Mouse wheel on the bar icon: ±10 %, snapped to multiples of 10, with an
  accumulator so a single smooth-scroll gesture doesn't overshoot.
- All `set` calls pass `--min-value=5` so the screen can't go fully black.

This widget overrides `BarPopupButton`'s click handling with its own
`MouseArea` (to catch wheel events), which also opens the popup.

---

## Audio

[`widgets/Audio.qml`](../widgets/Audio.qml) — Quickshell's PipeWire integration.

- `sink` is `Pipewire.defaultAudioSink`, kept bound with a `PwObjectTracker`
  (required for its `audio` properties to be live).
- Bar: volume icon and percentage; grey and no number while muted.
- Popup: mute button (same height as the slider), volume `FillSlider` (0–1,
  dimmed while muted but still works), and a list of output devices.
- Output list: PipeWire nodes that are sinks, have audio, aren't streams, and
  **whose description doesn't contain "DisplayPort"** (hides the HDMI/DP
  outputs that are always present). Tapping one sets
  `Pipewire.preferredDefaultAudioSink`.

The large commented-out block at the end is the previous version (with a
`ComboBox`); safe to delete.

---

## Battery

[`widgets/Battery.qml`](../widgets/Battery.qml) — `UPower.displayDevice` and
`PowerProfiles`.

- Low: ≤ 20 % and not charging (amber). Critical: ≤ 10 % (red).
- Popup: percentage, time to full / time to empty (and an estimate of the
  total runtime, `timeToEmpty * 100 / percentage`), a level bar, and three
  power-profile buttons (Power saver / Balanced / Performance; Performance is
  hidden if the machine doesn't offer it).
- Power profiles need **power-profiles-daemon** running.
- Guarded with `battery.ready` because UPower's display device is briefly
  unready at startup.

---

## System monitor

[`widgets/SysMonitor.qml`](../widgets/SysMonitor.qml) plus
[`widgets/sysmon/`](../widgets/sysmon). Data from
[`services/SystemStats.qml`](services.md#systemstats).

**Bar:** icon plus three tiny vertical meters: CPU (blue), memory (green), swap
(purple). Each turns amber at ≥ 80 % and red at ≥ 95 % (`levelColor`).

**Popup** (right side, full height, 560 px, keyboard focus for the filter fields):

1. Two `GraphCard`s: CPU, and memory + swap overlaid. Drawn by
   [`sysmon/Graph.qml`](../widgets/sysmon/Graph.qml), a `Canvas` that plots
   0–100 series with the newest sample on the right; the x axis always spans
   `SystemStats.historyLength` samples (10 minutes).
2. Tabs (`TabSwitcher`): Processes / Services.

### Processes page

[`widgets/sysmon/ProcessesPage.qml`](../widgets/sysmon/ProcessesPage.qml)

- One command per refresh:
  `ps -eo pid=,user:32=; echo ===; cat /proc/[0-9]*/stat`. `ps` is only used
  for user names; everything else is parsed from `/proc/<pid>/stat`.
- CPU % = Δ(utime + stime) / 100 ticks/s / elapsed seconds / cores, so it
  needs two samples. On opening it takes a second one after 500 ms. Clock
  ticks (100) and page size (4096) are hardcoded.
- Memory = RSS pages × 4096.
- Kernel threads (pid 2 and its children) are hidden.
- Sort by CPU / Memory / Name / PID; tap the active sort again to reverse.
  Filter matches name substring, exact PID, or exact user.
- The `ListModel` is updated in place (`set`/`append`/`remove`) so the scroll
  position survives refreshes.
- Tapping a row expands it: shows the full command line
  (`/proc/<pid>/cmdline`) and **End (SIGTERM)** / **Kill (SIGKILL)** buttons
  (`kill -s TERM|KILL -- pid`). While a row is expanded the list stops
  refreshing so rows don't move under your finger.
- Refreshes every `SystemStats.interval` (2 s) while visible, unless being
  scrolled.

### Services page

[`widgets/sysmon/ServicesPage.qml`](../widgets/sysmon/ServicesPage.qml)

- Scope: **User** or **System** services. System services are read-only
  (rows can't be expanded).
- Listing: `systemctl --user|--system list-units --type=service --all
  --output=json` merged with `list-unit-files --output=json`, so installed but
  never-loaded services also appear. Template units (`foo@.service`) and
  aliases are dropped.
- For user scope, services whose unit file is directly in
  `~/.config/systemd/user/` (or instances of a template there) are grouped
  first as **My services**; everything else is "Other services".
- Within each group: failed, then running/transitioning, then stopped, then
  by name. Status filter chips: All / Running / Failed (with a failed count).
- Expanded user-service row: **Start / Stop / Restart** (`systemctl --user
  <verb> -- unit`) and **Logs**, which shows the last 300 lines of
  `journalctl --user-unit=<unit>` with a Refresh button.
- Refreshes every 5 s while visible and the log view is closed.

---

## System tray

[`widgets/SysTray.qml`](../widgets/SysTray.qml) — `SystemTray.items`. Left click
activates, right click opens the item's menu (positioned under the icon via
`display(panelWindow, x, y)`, hence the `panelWindow` property passed from
`Bar.qml`). Tooltip is title + description.

---

## Clock

[`widgets/Clock.qml`](../widgets/Clock.qml) plus
[`widgets/timers/`](../widgets/timers). Keyboard focus is on (for the timer
name field).

**Bar:** `Time.time` (from [`widgets/Time.qml`](../widgets/Time.qml), which runs
`date +"%H : %M"` every second). When any timer exists, a timer icon appears
before the time (dimmed if all are paused). The whole thing fades to amber
while a running timer is close to finishing (`Timers.almostDone`).

**Popup:** current date/time header, then three tabs. The selected tab
(`page`) is remembered between openings.

### Calendar tab

- Each time the popup opens it jumps to today (`goToToday`).
- Month grid uses Qt Quick Controls' `MonthGrid`, `DayOfWeekRow` and
  `WeekNumberColumn`, with `locale: Qt.locale("en_GB")` so weeks start on
  Monday while names stay English (the system locale is en_US).
- Navigation: arrow buttons, horizontal swipe (> 40 px), or mouse wheel.
  Tapping a greyed day from the neighbouring month switches to that month and
  keeps it selected.
- Events: fetched from `CalendarEvents.fetch(from, to, cb)` for the shown
  month ±14 days (the grid shows parts of neighbouring months). Results are
  grouped into `eventsByDay` keyed by `YYYY-MM-DD`. A `requestToken` drops
  stale answers if the month changed before the reply arrived. It refetches
  when the service emits `updated` while the popup is open.
- Each day shows up to three dots in the event's calendar colour (fallback
  `#80bfff`). The selected day's events are listed below (scrolls after four),
  with "All day", "09:30 – 10:15", or "…" for a side that falls on another
  day.
- The events section is hidden entirely if the helper isn't running
  (`CalendarEvents.ready` false); the calendar grid still works.

Full calendar pipeline: [calendar.md](calendar.md).

### Timers tab

[`widgets/timers/TimersPage.qml`](../widgets/timers/TimersPage.qml) — UI for
[`services/Timers.qml`](services.md#timers).

- Running timers as cards: remaining time, label (or "5 min" etc.), progress
  bar, **+1 min**, pause/resume and cancel. Amber when within the warning
  threshold.
- New timer: h / min / s fields with up/down buttons that wrap around and
  auto-repeat while held (`HoldButton`: first step on press, then every 90 ms
  after 400 ms), presets (1, 3, 5, 10, 15, 30 min, 1 h), optional name (Enter
  starts it), and a "play a sound" toggle.

### Stopwatch tab

[`widgets/timers/StopwatchPage.qml`](../widgets/timers/StopwatchPage.qml) — UI
for [`services/Stopwatch.qml`](services.md#stopwatch). Big time display with
centiseconds, current lap time, Lap/Reset and Start/Pause/Resume buttons, and
a list of laps newest-first with the fastest in green and slowest in red (when
there are ≥ 2). Redraws every 10 ms only while running *and* visible.
