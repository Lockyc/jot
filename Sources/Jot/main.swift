import AppKit
import JotCore

// `Jot --print-shortcuts` prints the README's shortcut table from the registry and exits. The
// store is a throwaway folder: building the commands never reads it.
if CommandLine.arguments.contains("--print-shortcuts") {
    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("jot-print-shortcuts")
    print(Command.shortcutTable(JotController(store: NoteStore(folder: scratch)).makeCommands()))
    exit(0)
}

// AppKit's tooltip delay in ms (system default ~1000); the toolbar is icon-only, so its tooltips
// should come up quickly.
UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 300])

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

// AppKit exits on SIGTERM (pkill, killall, a logout) without applicationWillTerminate, so the
// final flush never ran; route the signal through terminate so pending edits are saved.
signal(SIGTERM, SIG_IGN)
let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigterm.setEventHandler { NSApp.terminate(nil) }
sigterm.resume()

app.run()
