<img src="Support/icon.png" alt="jot" width="128" height="128">

# jot

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-555)
![Swift](https://img.shields.io/badge/swift-6-F05138?logo=swift&logoColor=white)
[![License](https://img.shields.io/github/license/lockyc/jot)](LICENSE)

A hotkey scratchpad for macOS. One global shortcut shows and hides a floating panel of seven
plain-text notes, from whatever app is in front. Built for assembling text
from small pastes, with code-editor line operations and quick text actions.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/lockyc/jot/main/install.sh | bash
```

Needs macOS 14 or later. The installer downloads the latest release, checks that it is signed by
jot's developer and notarized by Apple, installs `/Applications/jot.app` and launches it. jot
lives in the menu bar; it has no Dock icon. After that jot updates itself: it checks daily, and
**Check for Updates…** in its menu checks now.

To build from source instead (needs Xcode's Swift 6 toolchain and
[`just`](https://github.com/casey/just)):

```bash
just install    # builds, copies to /Applications/jot.app and launches it
```

## Use

- **⌃⇧T** shows and hides the panel (change it in Settings, ⌘,). **⎋** also hides (with several carets, it first goes back to one).
- **Seven tabs**, ⌘1–⌘7, labelled by each note's first line. Each tab is a plain file in
  `~/Documents/jot/` (`1.txt` … `7.txt`) — grep it, edit it elsewhere; jot picks up outside edits
  the next time it shows. Nothing syncs.
- **Pin** a tab (⌘P, or right-click it) to keep reference text: Clear and Copy & Clear are
  disabled on a pinned tab.
- **⌘K** opens the command palette — every action below, searchable.

| Action | Shortcut |
|---|---|
| Clear Note | ⇧⌘⌫ |
| Copy & Clear Note | ⇧⌘C |
| Pin / Unpin Tab | ⌘P |
| Indent Lines | ⇥ / ⌘] |
| Outdent Lines | ⇧⇥ / ⌘[ |
| Move Line Up | ⌥↑ |
| Move Line Down | ⌥↓ |
| Duplicate Line / Selection | ⌘D |
| Delete Line | ⇧⌘K |
| Insert Line Below | ⌘↩ |
| Select Line | ⌘L |
| Split into Lines | ⇧⌘L |
| Add Caret Above | ⌃⇧↑ |
| Add Caret Below | ⌃⇧↓ |
| Toggle Word Wrap | ⌥Z |
| Paste Without Quote Gutter | ⌥⌘V |
| Paste Unwrapped | ⌃⌘V |
| Strip Quote Gutter | ⇧⌘V |
| Go to Tab 1 | ⌘1 |
| Go to Tab 2 | ⌘2 |
| Go to Tab 3 | ⌘3 |
| Go to Tab 4 | ⌘4 |
| Go to Tab 5 | ⌘5 |
| Go to Tab 6 | ⌘6 |
| Go to Tab 7 | ⌘7 |
| Command Palette | ⌘K |
| Settings… | ⌘, |
| Hide jot | ⎋ |
| Quit jot | ⌘Q |
| Dedent · Trim Trailing Whitespace · Sort Lines A→Z · Sort Lines Z→A · Remove Duplicate Lines · Remove Blank Lines · Unwrap Lines · Join Lines · Split on Delimiter… · UPPERCASE · lowercase · Title Case · Number Lines · Check for Updates… | ⌘K |

⌘F finds, ⌘Z after Clear restores the note, and ⌘L again extends the selection a line.

Typing behaves like a code editor: ↩ keeps the line's indent and continues a `- ` / `* ` bullet
or a `1. ` / `1) ` numbered list (↩ on an empty item ends the list), ⌫ in leading spaces removes one indent, and ⌘←
goes to the first non-blank character, then to column 0.

**Multiple carets** for editing lists: ⇧⌘L puts a caret at the end of every selected line,
⌃⇧↑ / ⌃⇧↓ add one above or below, ⌘-click adds one and ⌥-drag selects a column. Typing,
deleting, the arrow keys, ↩, paste (one clipboard line per caret when the counts match) and the
line operations act at every caret; ⎋ goes back to one.

Text actions work on the selection, or the whole note when nothing is selected, and each is one
undo step. **Strip quote gutter** removes the `│` / `|` / `▎` / `>` bar that comes along when
copying a quoted block out of Claude, then removes the shared indent; a markdown table inside a
`│` gutter keeps its own pipes. **Unwrap lines** rejoins the line breaks a terminal copy of a
Claude Code reply carries at the terminal's width, keeping paragraphs, list items, tables and
fenced code apart.

## Build & test

```bash
just test     # unit tests
just gate     # lint installer, build, tests, README shortcut table
just run      # build and launch build/jot.app
```
