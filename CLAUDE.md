---
type: architecture
links:
  - rel: covers
    to: Sources
  - rel: see-also
    to: README.md
    note: human-facing counterpart — what jot is and how to build it
  - rel: see-also
    to: docs/FOLLOWUPS.md
    note: deferred work — what is next
---

# jot — agent notes

Hotkey-toggled macOS scratchpad: a menu-bar app with a floating panel holding seven plain-text
notes. Swift package, AppKit, no third-party dependencies, macOS 14+. What's next:
[docs/FOLLOWUPS.md](docs/FOLLOWUPS.md).

## Layout

- `Sources/JotCore/` — pure Foundation: text transforms, line operations, fuzzy match, the
  hotkey toggle rule, persistence. **Every unit test lives here**; keep AppKit out of it.
- `Sources/Jot/` — the AppKit executable. `JotController` owns the panel, store, hotkey and
  tabs; `Commands.swift` is the command registry.
- `Tests/JotCoreTests/` — XCTest, `swift test`.
- `Support/Info.plist` — bundle template; `just bundle` stamps `VERSION` into it.

## Invariants

- **The toggle decision is `ToggleRule.action(panelVisible:appActive:)`, nothing else.** Never
  add selection, first responder or sheet state as an input — that is the bug jot replaces Tot
  over. Anything that would open a window over the panel (the ⌘K palette) is an overlay inside
  it instead, so the panel stays key.
- **`Commands.swift` is the single source for every action's title, shortcut and availability.**
  The key monitor, palette, toolbar buttons and status menu all read it; a new action is one
  registry entry and nothing else. Whether a key reaches the registry at all (editor focused, no
  IME composition, palette not focused) is `KeyRouting.route`. Tab/⇧Tab are the exception — `EditorView.insertTab`/
  `insertBacktab` — and the registry carries them only as a `hint`.
- Notes are plain files the user greps and edits: `~/Documents/jot/1.txt`…`7.txt` plus
  `state.json`. No sync of any kind.
- The README's shortcut table restates the registry; change both together.

## Build, test, verify, branches

- `just test`, `just gate`; `just run` builds and launches `build/jot.app`.
- Verify UI changes in the running app with `winshot` / `windrive`. Quit Tot first if it is
  running (`pkill -x Tot`): it holds ⌃⇧T too. A locked screen (front app `loginwindow`) swallows
  synthetic keys — check `lsappinfo front` before driving.
- Branches: `main` + `dev`. Work lands on `dev`; a release fast-forwards `main` from `dev`
  (`git merge --ff-only dev`). Docs-only changes may land on `main` and are forward-merged into
  `dev` immediately.
- Version: the root `VERSION` file is the only source; a release tags `v<VERSION>` and publishes
  a GitHub release with notes.
