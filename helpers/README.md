# Native helpers

Small native programs the Quickshell config runs for things QML can't do on
its own. Each helper lives in its own folder; this top-level CMake project
builds all of them.

| Helper | What it does | Used by |
| --- | --- | --- |
| [`calendar/`](calendar) (`corium-calendar`) | Reads KOrganizer's events from Akonadi | `services/CalendarEvents.qml` |

## Building

Needs CMake ≥ 3.30, a C++26 compiler, Qt 6 and, for the calendar helper,
`kcalendarcore`, `akonadi`, `akonadi-calendar` and `extra-cmake-modules`.

```sh
cmake -S helpers -B helpers/build -G Ninja
cmake --build helpers/build
ctest --test-dir helpers/build --output-on-failure
```

The QML expects the binaries in `helpers/build/`, so build there. A running
`corium-calendar` keeps using the old binary until it restarts (reloading the
Quickshell config is enough).

## corium-calendar

```sh
corium-calendar list 2026-10-01 2026-10-31   # print the events once, as JSON
corium-calendar serve                         # long-running mode used by Quickshell
```

`serve` reads one JSON request per line on stdin and writes one JSON message
per line on stdout; the protocol is documented in
[`calendar/src/protocol.h`](calendar/src/protocol.h). It only shows calendars
that are ticked in KOrganizer and reloads by itself when events, calendars or
that selection change.

The Akonadi-independent parts (expanding recurrences, the protocol, reading
KOrganizer's calendar selection) are in the `calendar_core` library and
covered by the tests in `calendar/tests/`.
