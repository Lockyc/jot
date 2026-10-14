public enum KeyRoute: Equatable {
    /// The palette's search field has focus: it handles Esc/↑/↓/↩/⌘K.
    case palette
    /// The palette is showing but focus left it (the panel was hidden, or the editor clicked):
    /// close it before anything else, so it never swallows keys typed into the editor.
    case closePalette
    /// The editor has focus and no IME composition is in progress: registry shortcuts apply.
    case commands
    /// Anything else (find bar, IME composition): AppKit handles the key.
    case passThrough
}

public enum KeyRouting {
    public static func route(paletteOpen: Bool, paletteFocused: Bool, editorFocused: Bool, composing: Bool) -> KeyRoute {
        if paletteOpen { return paletteFocused ? .palette : .closePalette }
        return editorFocused && !composing ? .commands : .passThrough
    }
}
