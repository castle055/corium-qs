# Calendar (KOrganizer events)

The clock popup shows events from KOrganizer. KOrganizer stores them in
**Akonadi**, which has no CLI and no D-Bus API that's practical to use from
QML, so the bar runs a small Qt/KDE C++ program, `corium-calendar`, that
reads Akonadi and answers requests over stdin/stdout.

```
Clock.qml ──fetch(from,to,cb)──▶ services/CalendarEvents.qml
                                     │ JSON line on stdin
                                     ▼
                        helpers/build/calendar/corium-calendar serve
                                     │ Akonadi (FetchJobCalendar, Monitor)
                                     │ korganizerrc (which calendars are ticked)
                                     ▼
                     JSON lines on stdout: ready / changed / events / error
```

The rest of the bar works without the helper; the clock just doesn't show the
events section.

## Building

```sh
cmake -S helpers -B helpers/build -G Ninja
cmake --build helpers/build
ctest --test-dir helpers/build --output-on-failure
```

Needs CMake ≥ 3.30, a C++26 compiler (`std::expected`,
`std::ranges::contains`), Qt 6, `kcalendarcore`, `akonadi`,
`akonadi-calendar`, and `extra-cmake-modules`. If the Akonadi packages
aren't found, CMake prints a warning and builds only the library and tests.

The QML expects the binary at exactly
`helpers/build/calendar/corium-calendar` (relative to `Quickshell.shellDir`).
`helpers/build/` is git-ignored. After rebuilding, reload Quickshell (or wait;
see below) so the old process is replaced.

`.vscode/settings.json` points the CMake extension at `helpers/`.

## Running it by hand

```sh
helpers/build/calendar/corium-calendar list 2026-10-01 2026-10-31   # one-shot, prints one events message
helpers/build/calendar/corium-calendar serve                        # what Quickshell runs
```

In `serve` mode you can type requests, e.g.
`{"id":1,"from":"2026-10-01","to":"2026-10-31"}`.

## Protocol

One compact JSON object per line. The authoritative description is the
comment at the top of
[`helpers/calendar/src/protocol.h`](../helpers/calendar/src/protocol.h).

Request (stdin):

```json
{"id": 7, "from": "2026-09-17", "to": "2026-11-14"}
```

`id` is echoed back unchanged and can be any JSON value. Dates are
`YYYY-MM-DD`, both inclusive; the range may be at most 366 days.

Messages (stdout):

```json
{"type":"ready"}
{"type":"changed"}
{"type":"events","id":7,
 "events":[{"uid":"…","summary":"Lecture","location":"2.1.A03","allDay":false,
            "start":"2026-10-05T09:30:00","end":"2026-10-05T11:00:00",
            "days":["2026-10-05"],"calendar":42}],
 "calendars":[{"id":42,"name":"University","color":"#3daee9"}]}
{"type":"error","id":7,"message":"…"}      // id is null if it couldn't be tied to a request
```

Event fields:

- `start`/`end` are local time **without** an offset. Timed events: `end` is
  exclusive. All-day events: plain dates, and `end` is the last day,
  inclusive.
- `days`: every date within the requested range that the occurrence touches.
  A timed event ending exactly at midnight doesn't touch the next day. The
  clock uses this to put multi-day events on each day.
- `calendar`: Akonadi collection id; look it up in `calendars` for the name
  and colour (colour may be `""`).
- Recurring events are expanded: one entry per occurrence, exceptions applied.
- Sorted by first day, all-day before timed, then start time, summary, uid.

## Helper internals (`helpers/calendar/src/`)

| File | Role |
| --- | --- |
| `main.cpp` | CLI (`serve`, `list`), stdin reading with `QSocketNotifier`, wiring signals to messages |
| `akonadisource.{h,cpp}` | Loads collections and events from Akonadi, watches for changes, filters by KOrganizer selection |
| `occurrences.{h,cpp}` | Expands recurrences into `Occurrence`s for a date range (pure KCalendarCore, testable) |
| `protocol.{h,cpp}` | Request parsing and message building (testable) |
| `selection.{h,cpp}` | Parses KOrganizer's calendar selection (testable) |

Everything except `akonadisource` and `main` is in the `calendar_core` static
library so it can be unit-tested without Akonadi running.

### Loading and reloading (`AkonadiSource`)

1. `start()`: set up an `Akonadi::Monitor` for event items and collections,
   watch `~/.config/korganizerrc`, load the selection, `reload()`.
2. `reload()`: `CollectionFetchJob` (recursive, events only) for names and
   colours, then a fresh `Akonadi::FetchJobCalendar` with all events. The new
   calendar replaces the old one only once it has fully loaded, so requests
   during a reload get the previous data, not a half-loaded one.
3. The first successful load emits `ready`; later ones emit `changed`.
   Reloads requested while one is running are queued (only one extra).
4. Any monitor notification (item added/changed/removed/moved, collection
   added/changed/removed) restarts a 500 ms single-shot timer, so a sync burst
   causes one reload.
5. When `korganizerrc` changes, only the selection is reloaded and `changed`
   is emitted. KConfig saves by replacing the file, which drops it from
   `QFileSystemWatcher`, so it's re-added each time.

The colour attribute type has to be registered
(`AttributeFactory::registerAttribute<CollectionColorAttribute>()`) or it
arrives as an opaque blob.

### Which calendars are shown

Only calendars ticked in KOrganizer's sidebar. KOrganizer saves that in
`korganizerrc`:

```ini
[GlobalCollectionSelection]
Selection=c12,c42,rakonadi_google_resource_0/abc@group.calendar.google.com
```

Entries are `c<collection id>` or `r<resource>/<remote id>`. If the key has
never been written, everything is shown. Events from a collection the helper
doesn't know about are shown rather than dropped.

### Recurrence expansion

`occurrencesInRange` uses `KCalendarCore::OccurrenceIterator`. The iterator
only finds occurrences that *start* within its range, so the range is started
**62 days early** (`lookbackDays`) to catch long occurrences that began before
the requested range and still overlap it. An event longer than that which
started before the window would be missed.

All-day dates are "floating" and kept as calendar dates; timed events are
converted to the system time zone.

### serve mode details

- Requests that arrive before the first load are queued and answered right
  after `ready`.
- If the **first** load fails (e.g. Akonadi isn't up yet), it prints an
  `error` and exits with status 1; QML restarts it 30 s later. Failures after
  that keep serving the last good data.
- It quits when stdin closes (Quickshell went away). Non-blocking-read
  `EAGAIN` is ignored because Quickshell may hand it a non-blocking pipe.
- `QCoreApplication::setQuitLockEnabled(false)` is needed because Akonadi jobs
  hold quit locks and the app would otherwise quit when the last job ends.

## QML side ([`services/CalendarEvents.qml`](../services/CalendarEvents.qml))

- Starts `corium-calendar serve` at startup. If it isn't running (not built,
  crashed, Akonadi down), `fetch` immediately calls back with `null`.
- Each `fetch` gets an incrementing id; callbacks wait in `callbacks[id]`
  until the matching `events`/`error` message arrives. If the process exits,
  every pending callback gets `null`.
- `ready` and `changed` messages both emit `updated()`; Clock refetches the
  visible month when the popup is open.
- Whenever the process stops, it's restarted after **30 s**. That's also how a
  freshly built helper gets picked up without reloading.
- `calendars` is converted from a list into an object keyed by id before
  being handed to the callback.

## Tests

`helpers/calendar/tests/` has Qt Test suites for `occurrences`, `protocol`
and `selection`, run through CTest with `TZ=Europe/Madrid` pinned so results
don't depend on the machine. They cover recurrence expansion edge cases
(midnight ends, multi-day, all-day, exceptions, lookback), request validation,
JSON output, and selection parsing. Run them after touching anything in
`calendar_core`.
