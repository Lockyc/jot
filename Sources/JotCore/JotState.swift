import Foundation

public struct HotKeySpec: Codable, Equatable {
    /// Carbon virtual key code and Carbon modifier mask (`cmdKey`, `shiftKey`, …).
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var display: String

    public init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }

    /// ⌃⇧T — kVK_ANSI_T (17), controlKey (0x1000) | shiftKey (0x200); the owner's Tot binding.
    public static let defaultToggle = HotKeySpec(keyCode: 17, modifiers: 0x1000 | 0x200, display: "⌃⇧T")
}

public struct JotSettings: Codable, Equatable {
    public var hotKey = HotKeySpec.defaultToggle
    /// nil = the system monospaced font.
    public var fontFamily: String? = nil
    public var fontSize: Double = 14
    public var indentWidth = 2
    public var spellcheck = false

    public init() {}

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotKey = (try? c.decodeIfPresent(HotKeySpec.self, forKey: .hotKey)) ?? hotKey
        fontFamily = (try? c.decodeIfPresent(String.self, forKey: .fontFamily)) ?? fontFamily
        fontSize = (try? c.decodeIfPresent(Double.self, forKey: .fontSize)) ?? fontSize
        indentWidth = (try? c.decodeIfPresent(Int.self, forKey: .indentWidth)) ?? indentWidth
        spellcheck = (try? c.decodeIfPresent(Bool.self, forKey: .spellcheck)) ?? spellcheck
    }
}

public struct JotState: Codable, Equatable {
    public var pinned = Array(repeating: false, count: NoteStore.tabCount)
    public var wrap = Array(repeating: true, count: NoteStore.tabCount)
    public var activeTab = 0
    /// `NSStringFromRect` of the panel frame.
    public var panelFrame: String? = nil
    public var settings = JotSettings()

    public init() {}

    /// Every field is optional on disk; a hand-edited or older file never fails the whole decode.
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinned = (try? c.decodeIfPresent([Bool].self, forKey: .pinned)) ?? pinned
        wrap = (try? c.decodeIfPresent([Bool].self, forKey: .wrap)) ?? wrap
        activeTab = (try? c.decodeIfPresent(Int.self, forKey: .activeTab)) ?? activeTab
        panelFrame = (try? c.decodeIfPresent(String.self, forKey: .panelFrame)) ?? panelFrame
        settings = (try? c.decodeIfPresent(JotSettings.self, forKey: .settings)) ?? settings
        self = normalized()
    }

    public func normalized() -> JotState {
        func fit(_ a: [Bool], _ pad: Bool) -> [Bool] {
            Array((a + Array(repeating: pad, count: NoteStore.tabCount)).prefix(NoteStore.tabCount))
        }
        var s = self
        s.pinned = fit(pinned, false)
        s.wrap = fit(wrap, true)
        s.activeTab = min(max(activeTab, 0), NoteStore.tabCount - 1)
        s.settings.indentWidth = min(max(settings.indentWidth, 1), 8)
        s.settings.fontSize = min(max(settings.fontSize, 8), 48)
        return s
    }
}

public enum NoteLabel {
    static let maxLength = 16

    /// A tab's label: its first non-blank line, truncated; its number when the note is empty.
    public static func make(text: String, index: Int) -> String {
        let first = text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty })
        guard let first else { return "\(index + 1)" }
        return first.count > maxLength ? String(first.prefix(maxLength)) + "…" : first
    }
}
