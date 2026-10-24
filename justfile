# `default` pipes `just --list` through a small stock-perl filter that clips long recipe
# docs to your terminal width (…) instead of wrapping. Self-contained — no external files;
# falls back to plain `just --list` where perl is absent. Edit the recipes below, not this.
# List available recipes
default:
    @if command -v perl >/dev/null 2>&1; then just --color always --list | perl -CS -Mutf8 -lpe 'BEGIN{($w)=`stty size 2>/dev/null </dev/tty`=~/ (\d+)/; $w||=100; $col=(-t STDOUT && !exists $ENV{NO_COLOR})} s/\e\[[0-9;]*m//g unless $col; (my $v=$_)=~s/\e\[[0-9;]*m//g; if(length($v)>$w){my($o,$n)=("",0); while(length && $n<$w-1){ if($col && s/^(\e\[[0-9;]*m)//){$o.=$1}else{s/^(.)//;$o.=$1;$n++} } $_=$o."…".($col?"\e[0m":"")}'; else just --list; fi

# Run the unit tests
test:
    swift test

# Pre-merge gate: lint the installer, build everything and run the tests
gate:
    shellcheck install.sh
    swift build
    swift test

app := "build/jot.app"
info_plist := "Support/Info.plist"

# Build build/jot.app (version from VERSION, Sparkle embedded; signed with APPLE_SIGNING_IDENTITY, else ad-hoc)
bundle:
    #!/usr/bin/env bash
    set -euo pipefail
    swift build -c release --product Jot
    bin=$(swift build -c release --show-bin-path)
    rm -rf {{app}}
    mkdir -p {{app}}/Contents/MacOS {{app}}/Contents/Frameworks
    cp "$bin/Jot" {{app}}/Contents/MacOS/Jot
    install_name_tool -add_rpath @executable_path/../Frameworks {{app}}/Contents/MacOS/Jot
    ditto "$bin/Sparkle.framework" {{app}}/Contents/Frameworks/Sparkle.framework
    cp {{info_plist}} {{app}}/Contents/Info.plist
    plutil -replace CFBundleShortVersionString -string "$(cat VERSION)" {{app}}/Contents/Info.plist
    plutil -replace CFBundleVersion -string "$(cat VERSION)" {{app}}/Contents/Info.plist
    # Inside-out: each nested Sparkle helper before the framework, the framework before the app.
    if [ -n "${APPLE_SIGNING_IDENTITY:-}" ]; then
        sign=(codesign --force --options runtime --timestamp --sign "$APPLE_SIGNING_IDENTITY")
    else
        sign=(codesign --force --sign -)
    fi
    sparkle={{app}}/Contents/Frameworks/Sparkle.framework
    "${sign[@]}" "$sparkle/Versions/B/XPCServices/Installer.xpc"
    "${sign[@]}" --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc"
    "${sign[@]}" "$sparkle/Versions/B/Autoupdate" "$sparkle/Versions/B/Updater.app" "$sparkle"
    "${sign[@]}" {{app}}

# Print the directory holding Sparkle's sign_update and generate_keys (resolving packages first)
sparkle-bin:
    @swift package resolve >/dev/null
    @echo "{{justfile_directory()}}/.build/artifacts/sparkle/Sparkle/bin"

# Build and launch the local bundle
run: bundle quit
    @just launch {{app}}

# Install to /Applications and launch
install: bundle quit
    rm -rf /Applications/jot.app
    cp -R {{app}} /Applications/jot.app
    @just launch /Applications/jot.app

# Quits any running Jot, force-killing one still alive after 3s.
[private]
quit:
    #!/usr/bin/env bash
    killall Jot 2>/dev/null || exit 0
    for _ in {1..30}; do pgrep -x Jot >/dev/null || exit 0; sleep 0.1; done
    killall -9 Jot 2>/dev/null
    while pgrep -x Jot >/dev/null; do sleep 0.1; done

# Opens the app at `path`, retrying for up to 5s: LaunchServices keeps a quit Jot on its
# books briefly after the process is gone, and `open` fails with error -600 until it lets go.
[private]
launch path:
    #!/usr/bin/env bash
    for _ in {1..20}; do open "{{path}}" 2>/dev/null && exit 0; sleep 0.25; done
    open "{{path}}"
