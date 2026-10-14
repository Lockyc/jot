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
