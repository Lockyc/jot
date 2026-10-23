# jot

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-555)
![Swift](https://img.shields.io/badge/swift-6-F05138?logo=swift&logoColor=white)
[![License](https://img.shields.io/github/license/lockyc/jot)](LICENSE)

A hotkey scratchpad for macOS. One global shortcut shows and hides a floating panel of seven
plain-text notes, from whatever app is in front. Built for assembling text
from small pastes, with code-editor line operations and quick text actions.

## Install

```bash
just install    # builds, signs locally, copies to /Applications/jot.app and launches it
```

Needs Xcode (Swift 6 toolchain) and [`just`](https://github.com/casey/just). jot lives in the
menu bar; it has no Dock icon.

## Use

- **⌃⇧T** shows and hides the panel (change it in Settings, ⌘,). **⎋** also hides.
- **Seven tabs**, ⌘1–⌘7, labelled by each note's first line. Each tab is a plain file in
  `~/Documents/jot/` (`1.txt` … `7.txt`) — grep it, edit it elsewhere; jot picks up outside edits
  the next time it shows. Nothing syncs.
- **Pin** a tab (⌘P, or right-click it) to keep reference text: Clear and Copy & Clear are
  disabled on a pinned tab.
- **⌘K** opens the command palette — every action below, searchable.

| Action | Shortcut |
|---|---|
| Clear note (⌘Z restores) | ⇧⌘⌫ |
| Copy & clear note | ⇧⌘C |
| Pin / unpin tab | ⌘P |
| Indent / outdent lines | ⇥ / ⇧⇥, ⌘] / ⌘[ |
| Move line up / down | ⌥↑ / ⌥↓ |
| Duplicate line or selection | ⌘D |
| Delete line | ⇧⌘K |
| Insert line below | ⌘↩ |
| Select line (repeat to extend) | ⌘L |
| Toggle word wrap | ⌥Z |
| Paste without quote gutter | ⌥⌘V |
| Strip quote gutter (selection, or whole note) | ⇧⌘V |
| Dedent · trim trailing whitespace · sort A→Z / Z→A · remove duplicate / blank lines · join lines · split on delimiter · UPPER / lower / Title case · number lines | ⌘K |
| Find | ⌘F |
| Settings | ⌘, |

Typing behaves like a code editor: ↩ keeps the line's indent and continues a `- ` or `* `
bullet (↩ on an empty bullet ends the list), ⌫ in leading spaces removes one indent, and ⌘←
goes to the first non-blank character, then to column 0.

Text actions work on the selection, or the whole note when nothing is selected, and each is one
undo step. **Strip quote gutter** removes the `│` / `|` / `▎` / `>` bar that comes along when
copying a quoted block out of Claude, then removes the shared indent; a markdown table inside a
`│` gutter keeps its own pipes.

## Build & test

```bash
just test     # unit tests
just gate     # build + tests
just run      # build and launch build/jot.app
```
