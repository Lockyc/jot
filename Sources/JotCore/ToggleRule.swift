public enum PanelAction: Equatable {
    case show, hide
}

public enum ToggleRule {
    /// The hotkey's whole decision. Selection, first responder, open sheets and the palette are
    /// deliberately not inputs — any of them gating the hide is the Tot bug jot exists to avoid.
    public static func action(panelVisible: Bool, appActive: Bool) -> PanelAction {
        panelVisible && appActive ? .hide : .show
    }
}
