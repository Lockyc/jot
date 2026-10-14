import AppKit
import JotCore

final class EditorView: NSTextView {
    var indentWidth = 2
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
            guard let container = textContainer else { return }
            if wraps {
                isHorizontallyResizable = false
                container.widthTracksTextView = true
                container.containerSize = NSSize(width: enclosingScrollView?.contentSize.width ?? frame.width,
                                                 height: CGFloat.greatestFiniteMagnitude)
                enclosingScrollView?.hasHorizontalScroller = false
                if let w = enclosingScrollView?.contentSize.width { setFrameSize(NSSize(width: w, height: frame.height)) }
            } else {
                isHorizontallyResizable = true
                container.widthTracksTextView = false
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                enclosingScrollView?.hasHorizontalScroller = true
            }
        }
    }

    /// Applies one edit as a single undo step.
    func apply(_ e: TextEdit) {
        guard let storage = textStorage, shouldChangeText(in: e.range, replacementString: e.replacement) else { return }
        storage.replaceCharacters(in: e.range, with: NSAttributedString(string: e.replacement, attributes: typingAttributes))
        didChangeText()
        setSelectedRange(e.selection)
        scrollRangeToVisible(e.selection)
    }

    var fullRange: NSRange { NSRange(location: 0, length: (string as NSString).length) }

    /// Runs `f` on the selection, or the whole note when nothing is selected.
    func transform(_ f: (String) -> String) {
        let sel = selectedRange()
        let whole = sel.length == 0
        let range = whole ? fullRange : sel
        let old = (string as NSString).substring(with: range)
        let new = f(old)
        guard new != old else { return }
        let newLength = (new as NSString).length
        apply(TextEdit(range: range, replacement: new,
                       selection: whole ? NSRange(location: min(sel.location, newLength), length: 0)
                                        : NSRange(location: range.location, length: newLength)))
    }

    func indentLines() { apply(LineOps.indent(string, selection: selectedRange(), unit: indentUnit)) }
    func outdentLines() { apply(LineOps.outdent(string, selection: selectedRange(), width: indentWidth)) }
    func moveLines(up: Bool) {
        let edit = up ? LineOps.moveUp(string, selection: selectedRange()) : LineOps.moveDown(string, selection: selectedRange())
        if let edit { apply(edit) }
    }
    func duplicateLines() { apply(LineOps.duplicate(string, selection: selectedRange())) }
    func selectLines() { setSelectedRange(LineOps.selectLine(string, selection: selectedRange())) }

    func pasteStrippingGutter() {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return }
        let text = TextActions.stripQuoteGutter(raw)
        let sel = selectedRange()
        apply(TextEdit(range: sel, replacement: text,
                       selection: NSRange(location: sel.location + (text as NSString).length, length: 0)))
    }

    func clearAll() {
        guard fullRange.length > 0 else { return }
        apply(TextEdit(range: fullRange, replacement: "", selection: NSRange(location: 0, length: 0)))
    }

    /// Tab: indent unit at the caret, or indent every touched line when there is a selection.
    override func insertTab(_ sender: Any?) {
        if selectedRange().length == 0 { insertText(indentUnit, replacementRange: selectedRange()) } else { indentLines() }
    }
    override func insertBacktab(_ sender: Any?) { outdentLines() }
}
