import AppKit

// AppKit's tooltip delay in ms (system default ~1000); the toolbar is icon-only, so its tooltips
// should come up quickly.
UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 300])

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
