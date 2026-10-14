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

    func show() {
        if store.reloadIfChangedOnDisk(activeTab) {
            undoManagers[activeTab].removeAllActions()
            loadTab(activeTab)
        }
        // activate(ignoringOtherApps:) rather than the cooperative activate(): an accessory app
        // summoned by a hotkey is not handed activation by the frontmost app.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(editor)
    }

    func hide() {
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
        editor.string = store.text(i)
        let length = (editor.string as NSString).length
        let saved = selections[i]
        let location = min(saved.location, length)
        editor.setSelectedRange(NSRange(location: location, length: min(saved.length, length - location)))
        editor.wraps = store.state.wrap[i]
        editor.scrollRangeToVisible(editor.selectedRange())
    }

    func toggleWrap() {
        let tab = activeTab
        store.updateState { $0.wrap[tab].toggle() }
        editor.wraps = store.state.wrap[tab]
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
        if command.disabledReason() == nil { command.run() } else { NSSound.beep() }
    }

    func run(_ id: String) {
        guard let command = commands.first(where: { $0.id == id }) else { return }
        perform(command)
    }

    /// Returns true when the event was consumed.
    func handleKey(_ event: NSEvent) -> Bool {
        let combo = KeyCombo(event: event)
        guard let command = commands.first(where: { $0.keys.contains(combo) }) else { return false }
        perform(command)
        return true
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
        if store.state.panelFrame == nil { panel.center() }

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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
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
        menu.addItem(withTitle: "Show jot", action: #selector(showFromMenu), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit jot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func showFromMenu() { show() }
}
