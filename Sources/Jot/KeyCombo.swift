import AppKit
import Carbon.HIToolbox

struct KeyCombo: Hashable {
    static let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    let keyCode: UInt16
    let mods: UInt

    init(_ keyCode: Int, _ mods: NSEvent.ModifierFlags = []) {
        self.keyCode = UInt16(keyCode)
        self.mods = mods.intersection(Self.relevant).rawValue
    }

    init(event: NSEvent) { self.init(Int(event.keyCode), event.modifierFlags) }

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: mods) }

    static func modifierGlyphs(_ f: NSEvent.ModifierFlags) -> String {
        (f.contains(.control) ? "⌃" : "") + (f.contains(.option) ? "⌥" : "")
            + (f.contains(.shift) ? "⇧" : "") + (f.contains(.command) ? "⌘" : "")
    }

    static let names: [Int: String] = [
        kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫", kVK_Return: "↩",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_ANSI_RightBracket: "]", kVK_ANSI_LeftBracket: "[", kVK_ANSI_Comma: ",",
        kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_V: "V", kVK_ANSI_Z: "Z",
        kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
    ]

    var display: String { Self.modifierGlyphs(modifiers) + (Self.names[Int(keyCode)] ?? "?") }

    /// Keys a recorded hotkey may use that have no character of their own; label-only, so
    /// `menuEquivalent` never reads them.
    static let keyNames: [Int: String] = [
        kVK_Space: "Space", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
        kVK_F19: "F19", kVK_F20: "F20", kVK_Help: "Help", kVK_ANSI_KeypadEnter: "⌤", kVK_ANSI_KeypadClear: "⌧",
    ]

    /// The label for a recorded key: by key code where it has no character, else the
    /// unshifted character (⌃⇧1 is "1", not "!").
    static func keyLabel(_ event: NSEvent) -> String {
        keyLabel(keyCode: Int(event.keyCode), unmodified: event.characters(byApplyingModifiers: []) ?? "")
    }

    /// `keyLabel(_:)` for a key code and the character it types with no modifiers. A key whose
    /// character can't be shown (none, a control code, blank, a function key's private-use glyph)
    /// is named by its code.
    static func keyLabel(keyCode: Int, unmodified: String) -> String {
        if let name = keyNames[keyCode] ?? names[keyCode] { return name }
        let label = unmodified.uppercased()
        let shown = !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && label.unicodeScalars.allSatisfy {
            !(0xE000...0xF8FF).contains($0.value) && !CharacterSet.controlCharacters.contains($0)
        }
        return shown ? label : "Key \(keyCode)"
    }

    /// NSMenuItem keyEquivalent for this combo (paired with `modifiers`).
    var menuEquivalent: String {
        switch Int(keyCode) {
        case kVK_Tab: "\t"
        case kVK_Escape: "\u{1b}"
        case kVK_Delete: "\u{8}"
        case kVK_Return: "\r"
        case kVK_UpArrow: String(Character(UnicodeScalar(UInt32(NSUpArrowFunctionKey))!))
        case kVK_DownArrow: String(Character(UnicodeScalar(UInt32(NSDownArrowFunctionKey))!))
        default: (Self.names[Int(keyCode)] ?? "").lowercased()
        }
    }
}

func carbonModifiers(_ f: NSEvent.ModifierFlags) -> UInt32 {
    var m: UInt32 = 0
    if f.contains(.command) { m |= UInt32(cmdKey) }
    if f.contains(.option) { m |= UInt32(optionKey) }
    if f.contains(.control) { m |= UInt32(controlKey) }
    if f.contains(.shift) { m |= UInt32(shiftKey) }
    return m
}
