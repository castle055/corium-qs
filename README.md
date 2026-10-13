**(Before all the stuff that Claude generated for me, I want to say that I started this project out of necessity. I needed a status bar for a tablet device and I did not have the time to spend developing it. So I decided to role-play "project manager" and get it done in about 3 hours rather than spending 3 weeks learning QML and any libraries/APIs involved. This repo is public in case somebody finds it useful, but honestly, I take no pride in whatever is in it. It works on my machine, it does the job, to me that's what matters right now. It took ten times less time than it would have had I developed it myself. It's not critical software nor am I making any guarantees, so don't judge me.)**

# corium

My [Quickshell](https://quickshell.org) bar for Hyprland, set up for a touchscreen
laptop that I mostly use for taking handwritten notes in Xournal++.

## AI disclosure

**I did not write most of this code. An AI coding assistant did (mainly Claude,
through Claude Code).** I said what I wanted, read and tested the result, and
asked for changes until it worked. Some of the code was never written by hand at
all, including the C++ helper in `helpers/`.

I'm saying this upfront because I have other projects that I do write myself,
and I don't want this one mixed up with them. Don't use this repo to judge what
I can do as a programmer, good or bad.

I made this bar because I needed one that worked on my machine, not because I
wanted to work on a bar. It isn't meant to be polished, general-purpose or
maintained for other people.

## What's in the bar

From left to right:

- **Notebook launcher**: browses a folder of Xournal++ notebooks, with
  thumbnails, and opens them.
- **App launcher**: desktop entries, with search, favourites and recent apps.
- **Workspaces**: Hyprland workspaces.
- **Open notebooks**: notebooks open in Xournal++, each kept in its own
  `doc:` special workspace.
- **Screenshot** and **on-screen keyboard** toggle buttons.
- **Wi-Fi**: network list, connecting (including 802.1X/eduroam) through iwd.
- **Brightness**, **audio** (volume and mute) and **battery**.
- **System monitor**: CPU, memory and swap bars, with graphs, a process list
  and a page for managing `systemd --user` services.
- **System tray**.
- **Clock**: popup with a calendar showing KOrganizer events, timers and a stopwatch.

Most popups have large controls so they're usable by touch.

## Requirements

It assumes an Arch-like system running Hyprland, and calls a number of programs
directly:

- Quickshell, Hyprland (`hyprctl`)
- iwd, `busctl`, `gdbus`, `iwctl`, `rfkill`, `pkexec` (Wi-Fi)
- `brightnessctl`
- PipeWire (audio, and `pw-play` for the timer alarm)
- UPower (battery)
- systemd / `journalctl` (services page)
- Xournal++ (notebooks)
- `wvkbd` (`wvkbd-deskintl`) for the on-screen keyboard
- A `screenshot` command on your `PATH` (my own script, not included)
- A Nerd Font for the icons
- For the calendar: KOrganizer/Akonadi and the `corium-calendar` helper (see below)

Some things are hardcoded for my setup, e.g. the notebook folder is
`/home/castle/Notes/Notebooks` in `widgets/NotebookLauncher.qml`.

## Running it

Put the repo in `~/.config/quickshell/corium` and run:

```sh
quickshell -c corium
```

The calendar events come from a small native helper that has to be built
first. Building it and what it does are described in
[`helpers/README.md`](helpers/README.md). The rest of the bar works without it.

## Layout

```
shell.qml        entry point
widgets/         the bar and everything in it (popups, pages, small shared controls)
services/        singletons that hold state or talk to the system (iwd, Hyprland, timers, ...)
helpers/         native helper programs (currently just corium-calendar)
```
