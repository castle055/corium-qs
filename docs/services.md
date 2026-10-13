# Services

Singletons in [`services/`](../services), registered in
[`services/qmldir`](../services/qmldir). Each section lists what the service
exposes and how it gets its data. The two large ones have their own pages:
[Iwd and Rfkill → connectivity.md](connectivity.md), [CalendarEvents → calendar.md](calendar.md).

| Service | Used by | Persists to |
| --- | --- | --- |
| [`LauncherState`](#launcherstate) | AppLauncher | `launcher.json` |
| [`Xournalpp`](#xournalpp) | notebook components | — (cache only) |
| [`Iwd`](#iwd) | Connectivity (WifiPage) | — (iwd's own storage) |
| [`Rfkill`](#rfkill) | Connectivity, BluetoothPage | `airplane.json` |
| [`CalendarEvents`](#calendarevents) | Clock | — |
| [`Timers`](#timers) | Clock, TimersPage | `timers.json` |
| [`Stopwatch`](#stopwatch) | StopwatchPage | `stopwatch.json` |
| [`SystemStats`](#systemstats) | SysMonitor, ProcessesPage | — |

State files live in `~/.local/state/quickshell/by-shell/<hash>/`. Deleting one
resets that feature.

---

## LauncherState

[`services/LauncherState.qml`](../services/LauncherState.qml)

```
favorites: list<string>          desktop entry IDs
recents:   list<string>          desktop entry IDs, most recent first, max 12
isFavorite(app) / toggleFavorite(app)
launchApplication(app)           moves app to the front of recents, then app.execute()
```

Backed by a `FileView` + `JsonAdapter` that writes on every change. Creates the
file if it doesn't exist.

---

## Xournalpp

[`services/Xournalpp.qml`](../services/Xournalpp.qml) — everything that touches
notebook files. Details of the notebook model are in [notebooks.md](notebooks.md).

```
open(file)                                         xournalpp <file>, detached
createNewVolume(notebookDir, fileName, template)   copy a template there, then open it once copied
lookupTemplate(notebookDir, template, cb)          resolve a template name to a .xopp path
getPageCount(path, cb)                             cb(n) or cb(-1)
generateThumbnail(path, mTime, cb)                 cb(pngPath) once a thumbnail exists
thumbnailDir    ~/.cache/quickshell/corium/notebook-thumbnails/
templateDir     ~/.local/share/quickshell/corium/notebook-templates/
```

Implementation notes:

- Everything is async via its own `run(command, cb)` / `run_script(script,
  args, cb)` (creates a `Process` per call, see
  [architecture.md](architecture.md#running-commands)).
- **Page count**: `.xopp` files are gzipped XML, so
  `gzip -dc | xmllint --xpath 'count(/xournal/page)'`; PDFs use `pdfinfo`.
- **Thumbnails**: file name is `<md5(path)>_<mtime as YYYYMMDD_HHMMSS>.png`.
  If it exists it's reused; otherwise every older thumbnail with the same hash
  is deleted and a new one made with `xournalpp-thumbnailer` (`.xopp`) or
  `pdftoppm -f 1 -singlefile -png -r 100` (PDF). Because the mtime is in the
  name, editing a notebook automatically invalidates its thumbnail.
- `templateDir` comes from `StandardPaths.AppDataLocation`, which for
  Quickshell resolves to `~/.local/share/quickshell`; the `.substring(7)` strips
  the `file://` prefix.
- `createNewVolume` only opens the new file once `cp` has exited
  successfully; otherwise it logs a warning.
- `lookupTemplate` strips a trailing `.xopp` from the template name and uses
  `"default"` for an empty one.

---

## Iwd

[`services/Iwd.qml`](../services/Iwd.qml) — Wi-Fi through iwd's D-Bus API.
See [connectivity.md](connectivity.md#wi-fi-iwd).

---

## Rfkill

[`services/Rfkill.qml`](../services/Rfkill.qml) — radio kill switches. See
[connectivity.md](connectivity.md#airplane-mode-rfkill).

```
devices: [{ id, type, device, soft, hard }]   from rfkill -J, live via rfkill event
available                                      there is a Wi-Fi or Bluetooth radio
airplaneMode                                   every Wi-Fi and Bluetooth radio is blocked
hardBlocked                                    a hardware switch is off
blocked(type)
radiosBeforeAirplane                           { wlan, bluetooth } that were on, or null
setAirplaneMode(on, cb)                        block all / unblock what was on; cb(ok, message)
unblock(type, cb)
```

Bluetooth has no service of its own: Quickshell's `Quickshell.Bluetooth`
already exposes BlueZ as live objects.

---

## CalendarEvents

[`services/CalendarEvents.qml`](../services/CalendarEvents.qml) — client for the
`corium-calendar` helper. See [calendar.md](calendar.md).

```
ready: bool                        helper has loaded events and answers requests
updated()                          signal: events may have changed, fetch again
fetch(fromDate, toDate, cb)        cb({ events, calendars }) or cb(null)
```

---

## Timers

[`services/Timers.qml`](../services/Timers.qml) — any number of countdown timers.

Each timer is a plain object:

```js
{ id, label, duration, endsAt, remaining, paused, sound }   // times in ms
```

A **running** timer's truth is `endsAt` (an absolute `Date.now()` timestamp);
a **paused** timer's truth is `remaining`. Pausing computes `remaining` from
`endsAt`; resuming sets `endsAt = now + remaining`. Because only timestamps are
stored, timers keep counting through reloads and while Quickshell is closed.

```
timers                        the list (read-only; change it through the functions)
active / counting             any timer / any running timer
almostDone                    a running timer is within warnThreshold
now                           ticks every 250 ms while something is counting
start(ms, label, sound)
pause(id) / resume(id) / cancel(id) / addTime(id, ms)
remaining(t) / progress(t) / warnThreshold(t)
format(ms)    "4:05", "1:02:03"
describe(ms)  "1 h 30 min"
soundFile     /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
```

- `warnThreshold` is the last 20 % of the duration, clamped to 5 s – 1 min.
- `addTime` grows `duration` too, so the progress bar stays truthful.
- Every 250 ms (only while some timer is running) `finishDue()` removes
  expired timers and notifies: `notify-send --urgency=critical --app-name=Clock`,
  plus `pw-play <soundFile>` if the timer asked for sound.
- On load, timers that expired while Quickshell wasn't running are reported
  once with "finished at HH:mm" and **no** sound (anything more than 5 s late
  counts as late).
- All mutations go through `save(list)` which replaces the whole array on the
  `JsonAdapter`; that's what triggers the write and the UI update. Don't mutate
  timer objects in place.

---

## Stopwatch

[`services/Stopwatch.qml`](../services/Stopwatch.qml)

```
running, started
startedAt     Date.now() when last started
accumulated   ms counted before that
laps          cumulative totals at each lap press, oldest first
elapsed(now)  accumulated + (running ? now - startedAt : 0)
start() / pause() / lap() / reset()
format(ms)    "01:23.45", "1:02:03.45"
```

Same timestamp idea as Timers. The service doesn't tick; the page calls
`elapsed(Date.now())` as often as it wants to redraw.

It's saved with `FileView.setText(JSON.stringify(...))` and loaded
synchronously (`blockLoading: true`) in `Component.onCompleted`, rather than
with `JsonAdapter`. The comment in the file explains: `JsonAdapter` didn't
reliably keep several properties written back-to-back, nor load an object held
in a `var`. If you're tempted to "clean it up" to match Timers, that's why it
isn't.

---

## SystemStats

[`services/SystemStats.qml`](../services/SystemStats.qml) — samples
`cat /proc/stat /proc/meminfo` every 2 s (`interval`).

```
cpu, memory, swap                 0–100
memoryTotal/Used, swapTotal/Used  bytes
cores                             number of cpuN lines
cpuHistory, memoryHistory, swapHistory   last 300 samples (10 min), oldest first
formatBytes(n)                    "1.2 GiB", "340 MiB"
```

- CPU % is from the delta of the aggregate `cpu` line between two samples;
  idle = idle + iowait.
- Memory "used" is `MemTotal - MemAvailable` (like `free`), so reclaimable
  cache isn't counted.
- It runs all the time (not only while the popup is open), since the bar
  meters need it.

