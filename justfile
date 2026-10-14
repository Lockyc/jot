# `default` pipes `just --list` through a small stock-perl filter that clips long recipe
# docs to your terminal width (…) instead of wrapping. Self-contained — no external files;
# falls back to plain `just --list` where perl is absent. Edit the recipes below, not this.
# List available recipes
default:
    @if command -v perl >/dev/null 2>&1; then just --color always --list | perl -CS -Mutf8 -lpe 'BEGIN{($w)=`stty size 2>/dev/null </dev/tty`=~/ (\d+)/; $w||=100; $col=(-t STDOUT && !exists $ENV{NO_COLOR})} s/\e\[[0-9;]*m//g unless $col; (my $v=$_)=~s/\e\[[0-9;]*m//g; if(length($v)>$w){my($o,$n)=("",0); while(length && $n<$w-1){ if($col && s/^(\e\[[0-9;]*m)//){$o.=$1}else{s/^(.)//;$o.=$1;$n++} } $_=$o."…".($col?"\e[0m":"")}'; else just --list; fi

# Run the unit tests
test:
    swift test

# Pre-merge gate: build everything and run the tests
gate:
    swift build
    swift test

app := "build/jot.app"

# Build build/jot.app (ad-hoc signed, version from VERSION)
bundle:
    swift build -c release --product Jot
    rm -rf {{app}}
    mkdir -p {{app}}/Contents/MacOS
    cp "$(swift build -c release --show-bin-path)/Jot" {{app}}/Contents/MacOS/Jot
    cp Support/Info.plist {{app}}/Contents/Info.plist
    plutil -replace CFBundleShortVersionString -string "$(cat VERSION)" {{app}}/Contents/Info.plist
    plutil -replace CFBundleVersion -string "$(cat VERSION)" {{app}}/Contents/Info.plist
    codesign --force --sign - {{app}}

# Build and launch the local bundle
run: bundle
    pkill -x Jot || true
    open {{app}}

# Install to /Applications and launch
install: bundle
    pkill -x Jot || true
    rm -rf /Applications/jot.app
    cp -R {{app}} /Applications/jot.app
    open /Applications/jot.app
