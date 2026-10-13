# Notebooks

The bar is built around taking handwritten notes in Xournal++. Two widgets
deal with that:

- the **notebook launcher** (leftmost button): browse notebooks, see page
  thumbnails, open a volume, create a new one;
- **open notebooks** (middle of the bar): one tab per open Xournal++ window.

## On-disk layout

```
~/Notes/Notebooks/                     basePath (hardcoded in widgets/NotebookLauncher.qml)
├── Some Folder/                       a plain directory → shown as a folder tile
│   └── Aerodynamics-1/                a *notebook*: has notebook.json
│       ├── notebook.json
│       ├── 00_Intro.xopp              "volumes": every .xopp / .pdf in the folder
│       ├── 01_Untitled.xopp
│       └── .templates/                optional per-notebook templates
│           └── Theory.xopp
└── Agenda/
    └── notebook.json
```

A directory is a **notebook** if it contains `notebook.json`; otherwise it's a
folder you can navigate into. The file can be empty-ish; all fields are optional:

```json
{
    "name": "Scratch Notes",          // shown instead of the folder name
    "color": "#002200",               // card background, default #001115
    "template": "College/Theory"      // template for new volumes, see below
}
```

`notebook.json` is watched, so edits show up live.

## Browsing (`widgets/notebooks/`)

```
NotebookManager          back / home buttons, title, holds currentPath
└─ NotebookDirView       lists one directory
   ├─ NotebookDirectoryModel   splits subdirectories into "folders" and "notebooks"
   │  └─ NotebookMarker (one per subdirectory)   loads <dir>/notebook.json
   ├─ DirectoryPreview   folder tile (2-column grid); tap → changeDir
   └─ NotebookPreview    one card per notebook: name + horizontal strip of volumes
      ├─ NotebookVolumeCard   thumbnail + page-count badge; tap → Xournalpp.open
      │  └─ XoppThumbnail     asks Xournalpp.generateThumbnail, shows the PNG
      └─ "+" card             create a new volume
```

- **NotebookManager** keeps `currentPath`; "back" strips the last path
  component, "home" goes to `basePath`. Both are disabled at the root.
- **NotebookDirectoryModel** uses a `FolderListModel` for subdirectories and
  an `Instantiator` that creates a `NotebookMarker` per directory. Each marker
  tries to load `notebook.json` synchronously; "ready" means it either loaded
  or failed. Two `ScriptModel`s (`directories`, `notebooks`) are recomputed
  whenever a `generation` counter is bumped (on add/remove/ready). That counter
  is the trick that makes `ScriptModel.values` re-evaluate; the comments in the
  file explain it.
- **NotebookPreview** lists `*.xopp` and `*.pdf` files sorted by name in a
  horizontal `ScrollView`, and scrolls to the right end (newest volume) on
  load. Card thumbnails are 92×129.
- **XoppThumbnail** regenerates when the file's mtime changes; it resets
  `image.source` to `""` first to defeat Qt's image cache.

## Creating a new volume

The "+" card at the end of a notebook strip:

1. Finds the highest two-digit prefix among existing volume names
   (`NN_…`) and picks the next one, so the new file is `NN_Untitled.xopp`.
   Files that don't start with two digits are ignored when picking the
   number (so a stray `notes.pdf` in the folder doesn't matter). With no
   numbered files, the first volume is `00_Untitled.xopp`.
2. Calls `Xournalpp.createNewVolume(dir, name, template)`.
3. The template is looked up in this order:
   1. `<notebook>/.templates/<template>.xopp`
   2. `~/.local/share/quickshell/corium/notebook-templates/<template>.xopp`
   3. `~/.local/share/quickshell/corium/notebook-templates/default.xopp`
4. The template is copied with `cp`, and the new file is opened in
   Xournal++ once the copy has finished. If the copy fails, a warning is
   logged and nothing is opened. Rename the file from inside Xournal++
   (Save As) or the file manager.

`template` is a name relative to a templates folder and may contain slashes
(`"College/Theory"`) to use subfolders. A trailing `.xopp` is accepted and
ignored, so `"Theory"` and `"Theory.xopp"` mean the same thing. When
`notebook.json` has no `template`, `"default"` is used.

## Thumbnails and page counts

Both are done in [`services/Xournalpp.qml`](../services/Xournalpp.qml); see
[services.md](services.md#xournalpp). Thumbnails are cached in
`~/.cache/quickshell/corium/notebook-thumbnails/` keyed by path hash and
mtime; it's safe to delete that folder.

Tools needed: `xournalpp-thumbnailer` (ships with Xournal++), `pdftoppm` and
`pdfinfo` (poppler), `gzip`, `xmllint` (libxml2).

## Open-notebook tabs

[`widgets/OpenNotebooks.qml`](../widgets/OpenNotebooks.qml) shows Hyprland
workspaces whose name starts with `doc:`. **This repo doesn't create those.**
The Hyprland config (`~/.config/hypr/hyprland.lua`) has a `window.open` hook
that moves every new Xournal++ window (`initial_class ==
"com.github.xournalpp.xournalpp"`) to its own workspace named
`doc:xournal-<pid>` and follows it:

```lua
hl.on("window.open", function(w)
    if w.initial_class ~= "com.github.xournalpp.xournalpp" then return end
    hl.dispatch(hl.dsp.window.move({
        window = w, workspace = "name:doc:xournal-" .. w.pid, follow = true,
    }))
end)
```

If the tabs stop appearing, check that hook first. Workspace naming only has
to keep the `doc:` prefix for the bar to pick it up.

Tab label is the window title up to the first `.`. Closing a tab sends the
window a normal close request (so Xournal++ can still ask to save), after first
switching away if that workspace was focused, so you don't end up on an empty
workspace.
