import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Jot

final class KeyLabelTests: OffscreenTestCase {
    /// What `characters(byApplyingModifiers: [])` can hand back across layouts: letters, a shifted
    /// symbol, nothing, a function key's private-use glyph, a control character, whitespace.
    let unmodified = ["a", "1", "!", "é", "", "\u{F710}", "\u{F739}", "\u{3}", "\u{10}", " ", "\u{A0}"]

    func isPrintable(_ label: String) -> Bool {
        !label.isEmpty && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && label.unicodeScalars.allSatisfy { !(0xE000...0xF8FF).contains($0.value) && !CharacterSet.controlCharacters.contains($0) }
    }

    /// Every key code, whatever its character, gets a label the status menu can show.
    func testEveryKeyCodeHasAPrintableLabel() {
        for code in 0...127 {
            for chars in unmodified {
                let label = KeyCombo.keyLabel(keyCode: code, unmodified: chars)
                XCTAssertTrue(isPrintable(label), "key code \(code) with \(chars.debugDescription) labels as \(label.debugDescription)")
            }
        }
    }

    func testNamedKeys() {
        XCTAssertEqual(KeyCombo.keyLabel(keyCode: kVK_Space, unmodified: " "), "Space")
        let fKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                     kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
        for (i, code) in fKeys.enumerated() {
            XCTAssertEqual(KeyCombo.keyLabel(keyCode: code, unmodified: "\u{F704}"), "F\(i + 1)")
        }
        XCTAssertEqual(KeyCombo.keyLabel(keyCode: kVK_ANSI_1, unmodified: "1"), "1")
        XCTAssertEqual(KeyCombo.keyLabel(keyCode: kVK_ANSI_T, unmodified: "t"), "T")
    }

    /// The label is the unshifted key: ⌃⇧1 reads "1" whatever modifiers the event carries.
    func testEventLabelIgnoresModifiers() {
        for code in [kVK_ANSI_1, kVK_ANSI_T, kVK_ANSI_Slash, kVK_Space, kVK_F5] {
            let plain = KeyCombo.keyLabel(keyEvent(code, []))
            XCTAssertTrue(isPrintable(plain), "key code \(code)")
            for flags: NSEvent.ModifierFlags in [[.shift], [.control, .shift], [.option], [.command, .option, .shift]] {
                XCTAssertEqual(KeyCombo.keyLabel(keyEvent(code, flags)), plain, "key code \(code) with \(flags)")
            }
        }
    }

    func keyEvent(_ code: Int, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                         keyCode: UInt16(code))!
    }
}
