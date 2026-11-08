import AppKit
import JotCore

/// The note editor. With one caret, typing, deleting and moving stay native (IME, typing-undo
/// coalescing, autocorrect); with several, `EditorView+Carets.swift` splices every caret explicitly
/// through `apply(_: MultiEdit)`.
final class EditorView: NSTextView {
    var indentWidth = 2
    /// The caret list while there are two or more, in document order; empty otherwise, when the
    /// native selection is the only one. AppKit holds only the non-empty ones (or the primary);
    /// the other empty carets are drawn by `draw(_:)`.
    var carets: [NSRange] = []
    /// The moving end of each caret, for ⇧-extended moves.
    var heads: [Int] = []
    /// Set while jot itself changes the native selection, so `setSelectedRanges` doesn't treat
    /// the change as the user leaving multi-caret mode.
    var settingCarets = false
    var indentUnit: String { String(repeating: " ", count: indentWidth) }

    func configurePlain() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        textContainerInset = NSSize(width: 10, height: 10)
        isVerticallyResizable = true
        autoresizingMask = [.width]
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }

    func applyFont(family: String?, size: Double) {
        let f = family.flatMap { NSFontManager.shared.font(withFamily: $0, traits: [], weight: 5, size: size) }
            ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        font = f
        typingAttributes[.font] = f
    }

    var wraps: Bool = true {
        didSet {
            guard wraps != oldValue, let container = textContainer else { return }
            if wraps {
                isHorizontallyResizable = false
                let width = enclosingScrollView?.contentSize.width ?? frame.width
                if let w = enclosingScrollView?.contentSize.width { setFrameSize(NSSize(width: w, height: frame.height)) }
                // A width-tracking container sits inside the insets; match what tracking would set.
                container.containerSize = NSSize(width: width - 2 * textContainerInset.width,
                                                 height: CGFloat.greatestFiniteMagnitude)
                container.widthTracksTextView = true
                enclosingScrollView?.hasHorizontalScroller = false
            } else {
                isHorizontallyResizable = true
                container.widthTracksTextView = false
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                enclosingScrollView?.hasHorizontalScroller = true
            }
        }
    }

    /// Every selection, in document order: the caret list when there are several, else the
    /// native selection.
    var selections: [NSRange] { carets.count > 1 ? carets : [selectedRange()] }
    var hasMultipleCarets: Bool { carets.count > 1 }

    /// Applies every splice as one change and one undo step, then selects `m.selections`.
    func apply(_ m: MultiEdit) {
        guard let storage = textStorage,
              shouldChangeText(inRanges: m.splices.map { NSValue(range: $0.range) }, replacementStrings: m.splices.map(\.replacement))
        else { return }
        breakUndoCoalescing()
        storage.beginEditing()
        for s in m.splices.reversed() {
            storage.replaceCharacters(in: s.range, with: NSAttributedString(string: s.replacement, attributes: typingAttributes))
        }
        storage.endEditing()
        didChangeText()
        setCarets(m.selections)
        scrollRangeToVisible(m.selections[0])
    }

    /// Runs `op` at every selection and applies the result; nothing happens when no op edits.
    func edit(_ op: (_ text: String, _ sel: NSRange) -> TextEdit?) {
        let text = string
        if let m = MultiEdit.perSelection(text, selections, { op(text, $0) }) { apply(m) }
    }

    var fullRange: NSRange { NSRange(location: 0, length: (string as NSString).length) }

    /// Runs `f` on each non-empty selection, or the whole note when nothing is selected.
    func transform(_ f: @escaping (String) -> String) {
        let ns = string as NSString
        if selections.allSatisfy({ $0.length == 0 }) {
            let caret = selections[0].location
            let new = f(string)
            guard new != string else { return }
            apply(MultiEdit(splices: [Splice(range: fullRange, replacement: new)],
                            selections: [NSRange(location: min(caret, (new as NSString).length), length: 0)]))
            return
        }
        edit { _, sel in
            guard sel.length > 0 else { return nil }
            let old = ns.substring(with: sel), new = f(old)
            return new == old ? nil : TextEdit(range: sel, replacement: new, selection: NSRange(location: sel.location, length: (new as NSString).length))
        }
    }

    func indentLines() { edit { [indentUnit] in LineOps.indent($0, selection: $1, unit: indentUnit) } }
    func outdentLines() { edit { [indentWidth] in LineOps.outdent($0, selection: $1, width: indentWidth) } }
    func moveLines(up: Bool) { if let m = LineOps.move(string, selections: selections, up: up) { apply(m) } }
    /// Carets alone duplicate their lines; otherwise each non-empty selection duplicates itself.
    func duplicateLines() {
        let allEmpty = selections.allSatisfy { $0.length == 0 }
        edit { allEmpty || $1.length > 0 ? LineOps.duplicate($0, selection: $1) : nil }
    }
    func deleteLines() { edit(LineOps.deleteLines) }
    func insertLineBelow() { edit(LineOps.insertLineBelow) }
    func selectLines() { let text = string; setCarets(selections.map { LineOps.selectLine(text, selection: $0) }) }

    /// Pastes the clipboard text through `f`, as one undo step.
    func paste(transforming f: (String) -> String) {
        guard let raw = NSPasteboard.general.string(forType: .string),
              let m = Carets.paste(string, selections, clipboard: f(raw)) else { return }
        apply(m)
    }

    func clearAll() {
        guard fullRange.length > 0 else { return }
        apply(MultiEdit(splices: [Splice(range: fullRange, replacement: "")], selections: [NSRange(location: 0, length: 0)]))
    }

    /// Tab: indent unit at the caret, or indent every touched line when there is a selection.
    override func insertTab(_ sender: Any?) {
        guard selections.allSatisfy({ $0.length == 0 }) else { indentLines(); return }
        if hasMultipleCarets {
            edit { [indentUnit] in Carets.replace($1, with: indentUnit) }
        } else {
            insertText(indentUnit, replacementRange: selectedRange())
        }
    }
    override func insertBacktab(_ sender: Any?) { outdentLines() }

    override func insertNewline(_ sender: Any?) { edit(LineOps.newline) }

    override func deleteBackward(_ sender: Any?) {
        if hasMultipleCarets { edit { [indentWidth] in Carets.deleteBackward($0, $1, indentWidth: indentWidth) }; return }
        let sel = selectedRange()
        if let e = LineOps.deleteBackward(string, selection: sel, width: indentWidth) {
            edit { _, _ in e }
        } else {
            super.deleteBackward(sender)
        }
    }

    override func moveToLeftEndOfLine(_ sender: Any?) {
        let move = { self.smartLineStart(extend: false) { super.moveToLeftEndOfLine(sender) } }
        if hasMultipleCarets { moveEach(extend: false, move) } else { move() }
    }
    override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {
        if hasMultipleCarets {
            moveEach(extend: true) { self.smartLineStart(extend: false) { super.moveToLeftEndOfLine(sender) } }
        } else {
            smartLineStart(extend: true) { super.moveToLeftEndOfLineAndModifySelection(sender) }
        }
    }

    /// Lets AppKit move to the visual line start first; only when that is the start of the
    /// logical line (not a wrapped continuation) does ⌘← go to the first non-blank instead.
    private func smartLineStart(extend: Bool, native: () -> Void) {
        let before = selectedRange()
        native()
        let after = selectedRange()
        let ns = string as NSString
        let lineStart = ns.lineRange(for: NSRange(location: after.location, length: 0)).location
        guard after.location == lineStart else { return }
        guard extend else {
            if before.length == 0 { setSelectedRange(NSRange(location: LineOps.smartLineStart(string, caret: before.location), length: 0)) }
            return
        }
        // The anchor is the end AppKit kept fixed; the moving end is the other one.
        let anchor = NSMaxRange(after)
        let moving = anchor == before.location ? NSMaxRange(before) : before.location
        guard ns.lineRange(for: NSRange(location: moving, length: 0)).location == lineStart else { return }
        let target = LineOps.smartLineStart(string, caret: moving)
        setSelectedRange(NSRange(location: min(target, anchor), length: abs(anchor - target)))
    }
}
