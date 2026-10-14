import AppKit
import Carbon.HIToolbox
import JotCore
import ServiceManagement

final class SettingsWindowController: NSWindowController {
    private unowned let controller: JotController
    private let hotKeyButton = NSButton(title: "", target: nil, action: nil)
    private let hotKeyStatus = NSTextField(labelWithString: "")
    private let fontPopup = NSPopUpButton()
    private let sizePopup = NSPopUpButton()
    private let indentPopup = NSPopUpButton()
    private let spellcheck = NSButton(checkboxWithTitle: "Check spelling while typing", target: nil, action: nil)
    private let loginItem = NSButton(checkboxWithTitle: "Launch jot at login", target: nil, action: nil)
    private var recorder: Any?
    static let sizes: [Double] = [11, 12, 13, 14, 15, 16, 18, 20, 24]
    static let indents = [2, 4, 8]

    init(controller: JotController) {
        self.controller = controller
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 240),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "jot Settings"
        window.level = .floating
        window.isReleasedWhenClosed = false
        super.init(window: window)

        hotKeyButton.target = self
        hotKeyButton.action = #selector(recordHotKey)
        hotKeyStatus.textColor = .systemRed
        fontPopup.addItem(withTitle: "System Monospaced")
        fontPopup.addItems(withTitles: NSFontManager.shared.availableFontFamilies.filter {
            NSFontManager.shared.font(withFamily: $0, traits: [], weight: 5, size: 12)?.isFixedPitch == true
        })
        fontPopup.target = self
        fontPopup.action = #selector(fontChanged)
        sizePopup.addItems(withTitles: Self.sizes.map { "\(Int($0)) pt" })
        sizePopup.target = self
        sizePopup.action = #selector(sizeChanged)
        indentPopup.addItems(withTitles: Self.indents.map { "\($0) spaces" })
        indentPopup.target = self
        indentPopup.action = #selector(indentChanged)
        spellcheck.target = self
        spellcheck.action = #selector(spellcheckChanged)
        loginItem.target = self
        loginItem.action = #selector(loginChanged)

        let hotKeyRow = NSStackView(views: [hotKeyButton, hotKeyStatus])
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Show / hide:"), hotKeyRow],
            [NSTextField(labelWithString: "Font:"), fontPopup],
            [NSTextField(labelWithString: "Size:"), sizePopup],
            [NSTextField(labelWithString: "Indent:"), indentPopup],
            [NSGridCell.emptyContentView, spellcheck],
            [NSGridCell.emptyContentView, loginItem],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowSpacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
        ])
        window.contentView = content
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func present() {
        refresh()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func refresh() {
        let s = controller.store.state.settings
        hotKeyButton.title = s.hotKey.display
        hotKeyStatus.stringValue = controller.hotKeyOK ? "" : "Taken by another app — record a different one"
        fontPopup.selectItem(withTitle: s.fontFamily ?? "System Monospaced")
        sizePopup.selectItem(at: Self.sizes.firstIndex(of: s.fontSize) ?? 3)
        indentPopup.selectItem(at: Self.indents.firstIndex(of: s.indentWidth) ?? 0)
        spellcheck.state = s.spellcheck ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func recordHotKey() {
        controller.hotKey.unregister()
        hotKeyButton.title = "Press a shortcut…  (⎋ cancels)"
        recorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(KeyCombo.relevant)
            if Int(event.keyCode) == kVK_Escape && flags.isEmpty {
                self.stopRecording()
                return nil
            }
            guard !flags.intersection([.command, .option, .control]).isEmpty else {
                NSSound.beep()
                return nil
            }
            let display = KeyCombo.modifierGlyphs(flags) + (event.charactersIgnoringModifiers ?? "").uppercased()
            let spec = HotKeySpec(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers(flags), display: display)
            self.controller.updateSettings { $0.hotKey = spec }
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let recorder { NSEvent.removeMonitor(recorder) }
        recorder = nil
        controller.registerHotKey()
        refresh()
    }

    @objc private func fontChanged() {
        let family = fontPopup.indexOfSelectedItem == 0 ? nil : fontPopup.titleOfSelectedItem
        controller.updateSettings { $0.fontFamily = family }
    }
    @objc private func sizeChanged() {
        let size = Self.sizes[sizePopup.indexOfSelectedItem]
        controller.updateSettings { $0.fontSize = size }
    }
    @objc private func indentChanged() {
        let width = Self.indents[indentPopup.indexOfSelectedItem]
        controller.updateSettings { $0.indentWidth = width }
    }
    @objc private func spellcheckChanged() {
        let on = spellcheck.state == .on
        controller.updateSettings { $0.spellcheck = on }
    }
    @objc private func loginChanged() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        refresh()
    }
}
