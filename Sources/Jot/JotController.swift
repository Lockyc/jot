import AppKit
import JotCore

final class JotController: NSObject, NSWindowDelegate, NSTextViewDelegate, NSMenuDelegate {
    let store: NoteStore
    let hotKey = HotKey()
    private(set) var panel: JotPanel!
    private(set) var editor: EditorView!
    private(set) var commands: [Command] = []
    private(set) var hotKeyOK = true
    private var scrollView: NSScrollView!
    private var banner: NSTextField!
    private var contentStack: NSStackView!
    private var statusItem: NSStatusItem!
    private var keyMonitor: Any?
    private var toolbar: ToolbarView!
    private(set) var palette: PaletteView!
    private lazy var settingsWindow = SettingsWindowController(controller: self)

    func openSettings() { settingsWindow.present() }
    /// Per-tab undo, so ⌘Z after a tab switch never replays another note's ranges.
    private let undoManagers = (0..<NoteStore.tabCount).map { _ in UndoManager() }
    private var selections = Array(repeating: NSRange(location: 0, length: 0), count: NoteStore.tabCount)

    var activeTab: Int { store.state.activeTab }

    init(store: NoteStore) {
        self.store = store
        super.init()
    }

    func start() {
        NSApp.mainMenu = MainMenu.build()
        buildPanel()
        rebuildCommands()
        toolbar = ToolbarView(lookup: { [unowned self] id in self.commands.first { $0.id == id } },
                              run: { [unowned self] id in self.run(id) })
        toolbar.tabs.onSelect = { [unowned self] in self.selectTab($0) }
        toolbar.tabs.populateMenu = { [unowned self] i, menu in
            let pinned = self.store.state.pinned[i]
            menu.addItem(withTitle: pinned ? "Unpin" : "Pin", action: #selector(self.pinFromMenu(_:)), keyEquivalent: "").tag = i
            menu.items.forEach { $0.target = self }
        }
        insertChromeRow(toolbar)
        palette = PaletteView(commands: { [unowned self] in self.commands },
                              perform: { [unowned self] in self.perform($0) })
        palette.onClose = { [unowned self] in self.panel.makeFirstResponder(self.editor) }
        palette.translatesAutoresizingMaskIntoConstraints = false
        let content = panel.contentView!
        content.addSubview(palette)
        NSLayoutConstraint.activate([
            palette.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor, constant: 36),
            palette.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            palette.widthAnchor.constraint(equalTo: content.widthAnchor, multiplier: 0.8),
            palette.heightAnchor.constraint(equalToConstant: 280),
        ])
        buildStatusItem()
        store.onSaveResult = { [weak self] in self?.showSaveError($0) }
        hotKey.onPress = { [weak self] in self?.toggle() }
        registerHotKey()
        applySettingsToEditor()
        loadTab(activeTab)
        installKeyMonitor()
        show()
    }

    func rebuildCommands() { commands = makeCommands() }

    // MARK: Toggle

    func toggle() {
        switch ToggleRule.action(panelVisible: panel.isVisible, appActive: NSApp.isActive) {
        case .hide: hide()
        case .show: show()
        }
    }

    /// Picks up an outside edit to the visible note before anything reads or rewrites the editor:
    /// on show, when the panel becomes key (clicked back into, no hotkey), and before every command.
    func reloadActiveIfChangedOnDisk() {
        guard store.reloadIfChangedOnDisk(activeTab) else { return }
        discardUndo(activeTab)
        loadTab(activeTab)
    }

    func show() {
        reloadActiveIfChangedOnDisk()
        // activate(ignoringOtherApps:) rather than the cooperative activate(): an accessory app
        // summoned by a hotkey is not handed activation by the frontmost app.
        NSApp.activate(ignoringOtherApps: true)
        centreOnCursor()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(editor)
    }

    func hide() {
        if palette.isOpen { palette.close() }
        flush()
        panel.orderOut(nil)
        NSApp.hide(nil)
    }

    func flush() {
        store.setText(editor.string, tab: activeTab)
        store.flushReportingResult()
    }

    // MARK: Hotkey + settings

    func registerHotKey() {
        hotKeyOK = hotKey.register(store.state.settings.hotKey)
        refreshStatusItem()
    }

    func updateSettings(_ change: (inout JotSettings) -> Void) {
        let before = store.state.settings
        store.updateState { change(&$0.settings) }
        if store.state.settings.hotKey != before.hotKey { registerHotKey() }
        applySettingsToEditor()
    }

    func applySettingsToEditor() {
        let s = store.state.settings
        editor.applyFont(family: s.fontFamily, size: s.fontSize)
        editor.indentWidth = s.indentWidth
        editor.isContinuousSpellCheckingEnabled = s.spellcheck
    }

    // MARK: Tabs

    func loadTab(_ i: Int) {
        // Close any open typing-undo group before the buffer changes under it.
        editor.breakUndoCoalescing()
        editor.string = store.text(i)
        let length = (editor.string as NSString).length
        let saved = selections[i]
        let location = min(saved.location, length)
        editor.setSelectedRange(NSRange(location: location, length: min(saved.length, length - location)))
        editor.wraps = store.state.wrap[i]
        editor.scrollRangeToVisible(editor.selectedRange())
        refreshChrome()
    }

    func selectTab(_ i: Int) {
        guard i != activeTab else { return }
        rememberSelection()
        store.setText(editor.string, tab: activeTab)
        store.updateState { $0.activeTab = i }
        if store.reloadIfChangedOnDisk(i) { discardUndo(i) }
        loadTab(i)
    }

    func togglePin(_ i: Int) {
        store.updateState { $0.pinned[i].toggle() }
        refreshChrome()
    }

    @objc private func pinFromMenu(_ sender: NSMenuItem) { togglePin(sender.tag) }

    func refreshChrome() {
        guard let toolbar else { return }
        let texts = (0..<NoteStore.tabCount).map(store.text)
        toolbar.tabs.update(labels: texts.enumerated().map { NoteLabel.make(text: $1, index: $0) },
                            empty: texts.map(\.isEmpty), pinned: store.state.pinned, active: activeTab)
        toolbar.update(wraps: store.state.wrap[activeTab])
    }

    func toggleWrap() {
        let tab = activeTab
        store.updateState { $0.wrap[tab].toggle() }
        editor.wraps = store.state.wrap[tab]
        refreshChrome()
    }

    func promptSplit() {
        let alert = NSAlert()
        alert.messageText = "Split on delimiter"
        alert.addButton(withTitle: "Split")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: ",")
        field.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: panel) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            let delimiter = field.stringValue
            self.editor.transform { TextActions.split($0, on: delimiter) }
        }
    }

    func rememberSelection() { selections[activeTab] = editor.selectedRange() }

    func discardUndo(_ tab: Int) { undoManagers[tab].removeAllActions() }

    // MARK: Commands

    func perform(_ command: Command) {
        reloadActiveIfChangedOnDisk()
        if command.disabledReason() == nil { command.run() } else { NSSound.beep() }
    }

    func run(_ id: String) {
        guard let command = commands.first(where: { $0.id == id }) else { return }
        perform(command)
    }

    /// Returns true when the event was consumed.
    func handleKey(_ event: NSEvent) -> Bool {
        let combo = KeyCombo(event: event)
        switch KeyRouting.route(paletteOpen: palette.isOpen, paletteFocused: palette.hasFocus,
                                editorFocused: panel.firstResponder === editor, composing: editor.hasMarkedText()) {
        case .palette:
            return palette.handleKey(combo)
        case .closePalette:
            palette.close()
            return handleKey(event)
        case .passThrough:
            return false
        case .commands:
            guard let command = commands.first(where: { $0.keys.contains(combo) }) else { return false }
            perform(command)
            return true
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    // MARK: Panel

    private func buildPanel() {
        let frame = store.state.panelFrame.map(NSRectFromString) ?? NSRect(x: 0, y: 0, width: 640, height: 480)
        panel = JotPanel(contentRect: frame, styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        panel.title = "jot"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 320, height: 200)
        panel.delegate = self

        banner = NSTextField(labelWithString: "")
        banner.drawsBackground = true
        banner.backgroundColor = .systemRed
        banner.textColor = .white
        banner.isHidden = true

        scrollView = NSScrollView(frame: NSRect(origin: .zero, size: frame.size))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        editor = EditorView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        editor.configurePlain()
        editor.delegate = self
        scrollView.documentView = editor

        contentStack = NSStackView(views: [banner, scrollView])
        contentStack.orientation = .vertical
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            banner.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
        ])
        panel.contentView = content
    }

    /// Inserts a full-width row above the editor.
    func insertChromeRow(_ view: NSView) {
        contentStack.insertArrangedSubview(view, at: 1)
        view.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    private func centreOnCursor() {
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(cursor, $0.frame, false) }) ?? NSScreen.main
        else { return }
        panel.setFrame(PanelPlacement.frame(size: panel.frame.size, centredOn: cursor, within: screen.visibleFrame),
                       display: false)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
    func windowDidBecomeKey(_ notification: Notification) { reloadActiveIfChangedOnDisk() }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }
    private func saveFrame() {
        let frame = NSStringFromRect(panel.frame)
        store.updateState { $0.panelFrame = frame }
    }
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { undoManagers[activeTab] }

    // MARK: Editor delegate

    func undoManager(for view: NSTextView) -> UndoManager? { undoManagers[activeTab] }

    func textDidChange(_ notification: Notification) {
        store.setText(editor.string, tab: activeTab)
        refreshChrome()
    }

    private func showSaveError(_ error: Error?) {
        banner.stringValue = error == nil ? "" : "  Can't save to \(store.folder.path) — retrying. Your edits are kept."
        banner.isHidden = error == nil
    }

    // MARK: Status item

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshStatusItem()
    }

    func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        let hotKey = store.state.settings.hotKey.display
        button.image = NSImage(systemSymbolName: hotKeyOK ? "note.text" : "exclamationmark.triangle",
                               accessibilityDescription: "jot")
        button.toolTip = hotKeyOK ? "jot (\(hotKey))" : "jot: \(hotKey) is taken — choose another in Settings"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "Show jot  \(store.state.settings.hotKey.display)", action: #selector(showFromMenu), keyEquivalent: "").target = self
        if !hotKeyOK {
            let warning = NSMenuItem(title: "\(store.state.settings.hotKey.display) is taken — choose another in Settings", action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
        }
        for group in Command.Group.allCases where group != .app {
            menu.addItem(.separator())
            let parent = NSMenuItem(title: group.rawValue, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            sub.autoenablesItems = false
            commands.filter { $0.group == group }.forEach { sub.addItem(CommandMenuItem($0)) }
            parent.submenu = sub
            menu.addItem(parent)
        }
        menu.addItem(.separator())
        commands.filter { $0.group == .app && $0.id != "hide" }.forEach { menu.addItem(CommandMenuItem($0)) }
    }

    @objc private func showFromMenu() { show() }
}
