# corium documentation

Notes for whoever has to change this bar next (most likely me, having forgotten
everything). The [top-level README](../README.md) says what the bar is and how to
run it; these pages explain how it works.

## Where to start

| If you want to… | Read |
| --- | --- |
| Understand how the pieces fit together | [architecture.md](architecture.md) |
| Change or fix something in a specific bar item | [bar-widgets.md](bar-widgets.md) |
| Change how state is read from the system (timers, stats, launcher, …) | [services.md](services.md) |
| Touch the notebook launcher, thumbnails, templates or the open-notebook tabs | [notebooks.md](notebooks.md) |
| Touch Wi-Fi, especially eduroam / 802.1X | [wifi.md](wifi.md) |
| Touch the calendar or the `corium-calendar` C++ helper | [calendar.md](calendar.md) |
| Know which programs, files and config outside this repo it depends on | [system-integration.md](system-integration.md) |
| Run, debug, add a widget, or check the known rough edges | [development.md](development.md) |

## The 30-second version

- It's a [Quickshell](https://quickshell.org) config. Quickshell runs QML and
  hot-reloads it when files change. Entry point: [`shell.qml`](../shell.qml),
  which creates [`widgets/Bar.qml`](../widgets/Bar.qml) once per screen.
- The bar is a row of **widgets** (`widgets/`). Most of them are a
  `BarPopupButton`: an icon in the bar that opens a black "organic" popup
  hanging off the bar's bottom edge.
- Anything that holds state or talks to the system for more than one widget
  lives in a **service** singleton (`services/`).
- Almost all system access is done by **running command-line tools** (`busctl`,
  `gdbus`, `brightnessctl`, `systemctl`, …) through Quickshell's
  `Process`, plus a few native Quickshell integrations (PipeWire, UPower,
  system tray, Hyprland).
- The one thing QML couldn't do is read KOrganizer's calendar, so that is a
  small C++/Qt program in `helpers/calendar/` that the clock talks to over
  stdin/stdout in JSON lines.
- It's built for one touchscreen laptop: big touch targets, hardcoded paths
  (`~/Notes/Notebooks`), and it leans on rules in the Hyprland config
  (`~/.config/hypr/hyprland.lua`) for the notebook workspaces.

## Repo map

```
shell.qml                     entry point; just instantiates Bar
widgets/
  Bar.qml                     the bar itself: one PanelWindow per screen, lays out everything
  NotebookLauncher.qml        notebooks popup (uses widgets/notebooks/)
  AppLauncher.qml             application launcher popup
  Workspaces.qml              workspaces 1–5
  OpenNotebooks.qml           tabs for open Xournal++ windows (doc:* workspaces)
  ScreenshotTool.qml          runs `screenshot`
  OnScreenKeyboardToggle.qml  toggles wvkbd
  Wifi.qml                    Wi-Fi popup (uses services/Iwd.qml)
  Brightness.qml              brightness popup (brightnessctl)
  Audio.qml                   volume / mute / output popup (PipeWire)
  Battery.qml                 battery + power profile popup (UPower)
  SysMonitor.qml              CPU/mem/swap meters, graphs, processes, services
  SysTray.qml                 StatusNotifier tray
  Clock.qml                   clock; popup with calendar, timers, stopwatch
  Time.qml                    singleton: the "HH : MM" string shown in the bar
  notebooks/                  notebook browser components
  sysmon/                     system monitor pages and the graph
  timers/                     timers and stopwatch pages of the clock popup
  utils/                      BarPopupButton, OrganicPopUp, FillSlider
services/
  qmldir                      registers the singletons below
  CalendarEvents.qml          talks to the corium-calendar helper
  Iwd.qml                     Wi-Fi via iwd's D-Bus API
  LauncherState.qml           launcher favourites / recents (persisted)
  Timers.qml                  countdown timers (persisted)
  Stopwatch.qml               stopwatch (persisted)
  SystemStats.qml             CPU / memory / swap sampling
  Xournalpp.qml               open notebooks, create volumes, thumbnails, page counts
helpers/                      native helpers (CMake project); currently corium-calendar
docs/                         you are here
```
