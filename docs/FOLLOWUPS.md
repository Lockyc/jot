---
type: roadmap
links:
  - rel: see-also
    to: CLAUDE.md
    note: architecture and invariants these items touch
---

# jot — follow-ups

Accepted limitations and small fixes not yet done. Remove an item when it lands.

- **⎿ gutter continuation lines.** Claude Code marks only the first line of tool output with
  `⎿`; stripping it leaves later lines indented by the marker's width. Next: replace the marker
  and its space with equal-width spaces before dedenting (`TextActions.stripQuoteGutter`).
- **Active tab button toggles off when clicked.** `.pushOnPushOff` flips it and `selectTab`
  returns early. Next: `refreshChrome()` on that path.
- **Tab labels rebuilt per keystroke.** `textDidChange` relabels all seven tabs. Next: relabel
  only the active one; matters once notes get large.
- **Launch at login is only in Settings.** The design put it in the status menu too. Next: a
  checkbox item in `menuNeedsUpdate`.
- **Palette/find typing joins the note's undo stack** (`windowWillReturnUndoManager` serves every
  field editor in the panel). Next: return the tab's manager only when the editor is first
  responder, keeping menu `undo:` routed to it.
- **Non-US keyboard layouts.** Shortcuts match physical key codes and ⌥Z takes Ω. Next: decide
  per-layout display, or remap.
- **Unwrap guesses the width.** `TextActions.unwrap` takes the widest line as the terminal width,
  so a selection of only code, with lines close to its own longest, can join; a token longer than
  the width (a URL) that the terminal split mid-word is rejoined with a space. Next: a sample of
  real Claude Code copies to tune `wrapSlack` and to detect mid-word splits (the line above
  fills the full width with no space in it).
- **CRLF in line operations.** `LineOps` splits on LF only; a CRLF note leaves a stray `\r` on
  line moves (jot itself writes LF).
