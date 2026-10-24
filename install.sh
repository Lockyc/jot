#!/usr/bin/env bash
# install.sh — install jot from its latest GitHub release.
#   curl -fsSL https://raw.githubusercontent.com/lockyc/jot/main/install.sh | bash
# Installs /Applications/jot.app and launches it; jot updates itself from then on.
# JOT_ZIP_URL and JOT_APP_DIR override the download and the install folder.
set -euo pipefail

main() {
    zip_url=${JOT_ZIP_URL:-https://github.com/lockyc/jot/releases/latest/download/jot.zip}
    app_dir=${JOT_APP_DIR:-/Applications}
    team=G9V8U6ZU5E

    fail() { echo "jot: $*" >&2; exit 1; }

    [ "$(uname)" = Darwin ] || fail "jot runs on macOS only."
    major=$(sw_vers -productVersion | cut -d. -f1)
    [ "$major" -ge 14 ] || fail "jot needs macOS 14 or later; this Mac runs $(sw_vers -productVersion)."

    # Runs a command as the user, or with sudo when $1 (a directory) isn't writable.
    in_dir() {
        local dir=$1
        shift
        if [ -w "$dir" ]; then "$@"; else sudo "$@"; fi
    }

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    echo "→ downloading jot"
    curl -fsSL "$zip_url" -o "$work/jot.zip" || fail "couldn't download $zip_url"
    ditto -x -k "$work/jot.zip" "$work/unzipped" || fail "the download isn't a zip."
    new="$work/unzipped/jot.app"
    [ -d "$new" ] || fail "the download holds no jot.app."
    [ -z "$(find "$work/unzipped" -maxdepth 1 -type l)" ] && [ ! -L "$new" ] \
        || fail "the download's jot.app is a link."
    codesign --verify --strict --deep "$new" 2>/dev/null || fail "the download's signature doesn't verify."
    info=$(codesign -dv "$new" 2>&1) || fail "the download's signature can't be read."
    printf '%s\n' "$info" | grep -qx "TeamIdentifier=$team" \
        || fail "the download isn't signed by jot's developer."
    spctl --assess --type execute "$new" 2>/dev/null || fail "macOS won't open the download: it isn't notarized."
    version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$new/Contents/Info.plist")

    if pgrep -U "$(id -u)" -x Jot >/dev/null; then
        echo "→ quitting the running jot"
        pkill -U "$(id -u)" -x Jot || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -U "$(id -u)" -x Jot >/dev/null || break; sleep 0.5; done
        ! pgrep -U "$(id -u)" -x Jot >/dev/null || fail "jot didn't quit; quit it from its menu and re-run."
    fi

    target="$app_dir/jot.app"
    echo "→ installing jot $version to $target"
    [ -d "$app_dir" ] || in_dir "$(dirname "$app_dir")" mkdir -p "$app_dir"
    staged="$app_dir/.jot.app.new"
    in_dir "$app_dir" rm -rf "$staged"
    in_dir "$app_dir" ditto "$new" "$staged" || fail "couldn't copy jot into $app_dir."
    old="$app_dir/.jot.app.old"
    in_dir "$app_dir" rm -rf "$old"
    if [ -e "$target" ]; then
        in_dir "$app_dir" mv "$target" "$old" \
            || fail "couldn't move the old $target aside. Allow your terminal in System Settings > Privacy & Security > App Management, or drag the old app to the Trash, then re-run."
    fi
    if ! in_dir "$app_dir" mv "$staged" "$target"; then
        [ ! -e "$old" ] || in_dir "$app_dir" mv "$old" "$target" || true
        fail "couldn't move jot into place at $target."
    fi
    in_dir "$app_dir" rm -rf "$old"

    open "$target" || fail "$target didn't launch."
    echo "✓ jot $version is in $target and running in the menu bar (⌃⇧T shows it)."
}

main "$@"
