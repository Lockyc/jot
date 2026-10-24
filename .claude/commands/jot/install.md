You are installing or updating **jot** — a hotkey scratchpad for the macOS menu bar.

## 1. Check the Mac

```bash
sw_vers -productVersion
```

jot needs macOS 14 or later. On an older Mac, say so and stop.

## 2. Install

From a jot checkout (`[ -f install.sh ] && [ -f Package.swift ]`), ask with AskUserQuestion:
- **Latest release** (recommended): `bash install.sh`
- **This checkout's code**: `just install`

Outside a checkout, run `curl -fsSL https://raw.githubusercontent.com/lockyc/jot/main/install.sh | bash`.

If the installer needs `sudo`, the user types their password in this session: suggest `! <the command>`.

## 3. Check it is running

```bash
pgrep -x Jot && /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' /Applications/jot.app/Contents/Info.plist
```

Expect a process id and the installed version. If Tot is running it holds ⌃⇧T too: say so, and that jot's shortcut can be changed in its Settings (⌘,).

## 4. Done

Report the version, that **⌃⇧T** shows and hides jot, and that it updates itself (its menu-bar menu → **Check for Updates…** checks now).
