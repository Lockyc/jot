---
type: architecture
links:
  - rel: covers
    to: Sources
  - rel: see-also
    to: README.md
    note: human-facing counterpart — what jot is and how to build it
---

# jot — agent notes

Hotkey-toggled macOS scratchpad: a menu-bar app with a floating panel holding seven plain-text
notes. Swift package, AppKit, no third-party dependencies, macOS 14+.

## Layout

- `Sources/JotCore/` — pure Foundation: text transforms, line operations, fuzzy match, the
  hotkey toggle rule, persistence. **Every unit test lives here**; keep AppKit out of it.
- `Sources/Jot/` — the AppKit executable.
- `Tests/JotCoreTests/` — XCTest, `swift test`.

## Invariants

- **The toggle decision is `ToggleRule.action(panelVisible:appActive:)`, nothing else.** Never
  add selection, first responder or sheet state as an input — that is the bug jot replaces Tot
  over.
- Notes are plain files the user greps and edits: `~/Documents/jot/1.txt`…`7.txt` plus
  `state.json`. No sync of any kind.

## Build, test, branches

- `just test`, `just gate`.
- Branches: `main` + `dev`. Work lands on `dev`; a release fast-forwards `main` from `dev`
  (`git merge --ff-only dev`). Docs-only changes may land on `main` and are forward-merged into
  `dev` immediately.
- Version: the root `VERSION` file is the only source; a release tags `v<VERSION>` and publishes
  a GitHub release with notes.
