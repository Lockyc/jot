/// The panel's decisions: what showing, hiding, saving, switching tabs, running a command and
/// the panel becoming key each do, as effects over a snapshot of the state they depend on.
/// `JotController` builds the snapshot from the panel, palette and store each time and performs
/// the effects in order; it decides nothing itself. The snapshot is never stored, so the panel,
/// palette and store stay the only owners of their state.
public struct PanelSession: Equatable {
    public var visible: Bool
    public var appActive: Bool
    public var paletteOpen: Bool
    public var activeTab: Int

    public init(visible: Bool, appActive: Bool, paletteOpen: Bool, activeTab: Int) {
        self.visible = visible
        self.appActive = appActive
        self.paletteOpen = paletteOpen
        self.activeTab = activeTab
    }

    public enum Effect: Equatable {
        /// Load the active note from disk when it changed there and holds no pending jot edit
        /// (`NoteStore.reloadIfChangedOnDisk`), dropping its undo history.
        case pickUpOutsideEdit
        case activateApp
        /// Move the panel to the cursor's screen, centred on the cursor.
        case centre
        case orderFront
        case focusEditor
        case openPalette
        case closePalette
        /// The editor's text into the store, as the active note's.
        case writeBack
        case flush
        case orderOut
        case hideApp
        /// Keep the active tab's selection for when it is selected again.
        case rememberSelection
        /// Make the tab active, pick up its outside edit and load it into the editor.
        case switchTo(Int)
        case refreshChrome
        case runCommand
    }

    /// The hotkey: `ToggleRule` picks hide or show.
    public func toggle() -> [Effect] {
        switch ToggleRule.action(panelVisible: visible, appActive: appActive) {
        case .hide: hide()
        case .show: show()
        }
    }

    /// An outside edit is picked up before anything reads the editor. Only a panel coming on
    /// screen moves; one already showing (⌘K, the hotkey from another app) stays where the user
    /// put it.
    public func show() -> [Effect] {
        [.pickUpOutsideEdit, .activateApp] + (visible ? [] : [.centre]) + [.orderFront, .focusEditor]
    }

    /// The palette closes with the panel, so it never reopens over the editor swallowing keys.
    public func hide() -> [Effect] {
        (paletteOpen ? [.closePalette] : []) + save() + [.orderOut, .hideApp]
    }

    /// Everything the editor holds, on disk.
    public func save() -> [Effect] { [.writeBack, .flush] }

    public func openPalette() -> [Effect] { show() + [.openPalette] }

    /// Selecting the active tab changes nothing but still redraws the strip: its buttons are
    /// .pushOnPushOff, so the click that got here turned the active one off.
    public func selectTab(_ tab: Int) -> [Effect] {
        tab == activeTab ? [.refreshChrome] : [.rememberSelection, .writeBack, .switchTo(tab)]
    }

    /// Every command reads or rewrites the editor, so an outside edit is picked up first.
    public func command() -> [Effect] { [.pickUpOutsideEdit, .runCommand] }

    /// Clicked back into, with no hotkey: the note may have changed on disk meanwhile.
    public func becameKey() -> [Effect] { [.pickUpOutsideEdit] }
}
