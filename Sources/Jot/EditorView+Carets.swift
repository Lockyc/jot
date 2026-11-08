import AppKit
import JotCore

/// Multiple carets: state changes, drawing, and the per-caret forms of AppKit's editing and
/// movement commands. Every override here falls through to `super` with one caret.
extension EditorView {
    /// Selects `ranges` (normalized); one range or none is a plain native selection.
    func setCarets(_ ranges: [NSRange]) {
        setCarets(pairs: MultiEdit.normalize(ranges).map { ($0.location, NSMaxRange($0)) })
    }

    /// Selects one range per (anchor, head) pair, keeping each head for later ⇧-extended moves.
    func setCarets(pairs: [(anchor: Int, head: Int)]) {
        let byRange = pairs.map { (range: NSRange(location: min($0.anchor, $0.head), length: abs($0.head - $0.anchor)), head: $0.head) }
        let ranges = MultiEdit.normalize(byRange.map(\.range))
        settingCarets = true
        defer { settingCarets = false }
        if ranges.count <= 1 {
            carets = []
            heads = []
            setSelectedRange(ranges.first ?? NSRange(location: 0, length: 0))
        } else {
            carets = ranges
            // A range that merged with another has no single head; it extends from its end.
            heads = ranges.map { r in byRange.first { $0.range == r }?.head ?? NSMaxRange(r) }
            let shown = ranges.filter { $0.length > 0 }
            setSelectedRanges((shown.isEmpty ? [ranges[0]] : shown).map { NSValue(range: $0) },
                              affinity: .downstream, stillSelecting: false)
        }
        setNeedsDisplay(visibleRect)
    }

    /// ⎋ with several carets: keep only the first. false when there was only one.
    @discardableResult func collapseToPrimary() -> Bool {
        guard hasMultipleCarets else { return false }
        let primary = carets[0]
        setCarets([primary])
        scrollRangeToVisible(primary)
        return true
    }

    func splitIntoLines() { setCarets(Carets.splitIntoLines(string, selections)) }

    func addCaret(up: Bool) {
        let next = Carets.addVertical(string, selections, up: up)
        setCarets(next)
        if let edge = up ? next.first : next.last { scrollRangeToVisible(edge) }
    }

    // MARK: Leaving and entering multi-caret mode

    /// Any selection change jot didn't make (a click, ⌘A, find, undo, a tab load) ends multi-caret
    /// mode; one that sets several ranges itself (⌥-drag) starts it.
    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        guard !settingCarets else { return }
        let wasMulti = hasMultipleCarets
        carets = ranges.count > 1 ? MultiEdit.normalize(ranges.map(\.rangeValue)) : []
        if carets.count < 2 { carets = [] }
        heads = carets.map(NSMaxRange)
        if wasMulti || hasMultipleCarets { setNeedsDisplay(visibleRect) }
    }

    /// Commands with a per-caret form below; any other text command first collapses to one caret.
    /// `noop:` is an unbound key, which changes nothing.
    static let perCaretCommands: Set<Selector> = [
        Selector(("noop:")),
        #selector(insertTab(_:)), #selector(insertBacktab(_:)), #selector(insertNewline(_:)),
        #selector(deleteBackward(_:)), #selector(deleteForward(_:)),
        #selector(deleteWordBackward(_:)), #selector(deleteWordForward(_:)),
        #selector(deleteToBeginningOfLine(_:)), #selector(deleteToEndOfLine(_:)),
        #selector(moveLeft(_:)), #selector(moveRight(_:)), #selector(moveUp(_:)), #selector(moveDown(_:)),
        #selector(moveWordLeft(_:)), #selector(moveWordRight(_:)),
        #selector(moveToLeftEndOfLine(_:)), #selector(moveToRightEndOfLine(_:)),
        #selector(moveLeftAndModifySelection(_:)), #selector(moveRightAndModifySelection(_:)),
        #selector(moveUpAndModifySelection(_:)), #selector(moveDownAndModifySelection(_:)),
        #selector(moveWordLeftAndModifySelection(_:)), #selector(moveWordRightAndModifySelection(_:)),
        #selector(moveToLeftEndOfLineAndModifySelection(_:)), #selector(moveToRightEndOfLineAndModifySelection(_:)),
    ]

    override func doCommand(by selector: Selector) {
        if hasMultipleCarets, !Self.perCaretCommands.contains(selector) { collapseToPrimary() }
        super.doCommand(by: selector)
    }

    // MARK: Drawing

    /// The extra carets go in `drawBackground(in:)`: overriding `draw(_:)` drops an NSTextView to
    /// TextKit 1.
    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        guard hasMultipleCarets, let window else { return }
        let native = selectedRanges.map(\.rangeValue)
        insertionPointColor.setFill()
        for c in carets where c.length == 0 && !(native.count == 1 && native[0] == c) {
            let onScreen = firstRect(forCharacterRange: c, actualRange: nil)
            guard onScreen.height > 0 else { continue }
            let r = convert(window.convertFromScreen(onScreen), from: nil)
            let bar = NSRect(x: r.minX, y: r.minY, width: 1, height: r.height)
            if bar.intersects(dirtyRect) { bar.fill() }
        }
    }

    // MARK: Moving

    /// Runs a native move at each caret in turn and keeps the results. Extending moves run the
    /// plain move from the caret's head and keep its anchor.
    func moveEach(extend: Bool, _ move: () -> Void) {
        var pairs: [(anchor: Int, head: Int)] = []
        settingCarets = true
        for (c, head) in zip(carets, heads) {
            let anchor = head == c.location ? NSMaxRange(c) : c.location
            setSelectedRange(extend ? NSRange(location: head, length: 0) : c)
            move()
            let moved = selectedRange()
            pairs.append(extend ? (anchor, moved.location) : (moved.location, moved.location))
        }
        settingCarets = false
        setCarets(pairs: pairs)
        scrollRangeToVisible(selections[0])
    }

    override func moveLeft(_ sender: Any?) { hasMultipleCarets ? moveEach(extend: false) { super.moveLeft(sender) } : super.moveLeft(sender) }
    override func moveRight(_ sender: Any?) { hasMultipleCarets ? moveEach(extend: false) { super.moveRight(sender) } : super.moveRight(sender) }
    override func moveUp(_ sender: Any?) { hasMultipleCarets ? moveEach(extend: false) { super.moveUp(sender) } : super.moveUp(sender) }
    override func moveDown(_ sender: Any?) { hasMultipleCarets ? moveEach(extend: false) { super.moveDown(sender) } : super.moveDown(sender) }
    override func moveWordLeft(_ sender: Any?) { hasMultipleCarets ? moveEach(extend: false) { super.moveWordLeft(sender) } : super.moveWordLeft(sender) }
    override func moveWordRight(_ sender: Any?) { hasMultipleCarets ? moveEach(extend: false) { super.moveWordRight(sender) } : super.moveWordRight(sender) }
    override func moveToRightEndOfLine(_ sender: Any?) {
        hasMultipleCarets ? moveEach(extend: false) { super.moveToRightEndOfLine(sender) } : super.moveToRightEndOfLine(sender)
    }

    override func moveLeftAndModifySelection(_ sender: Any?) {
        hasMultipleCarets ? moveEach(extend: true) { super.moveLeft(sender) } : super.moveLeftAndModifySelection(sender)
    }
    override func moveRightAndModifySelection(_ sender: Any?) {
        hasMultipleCarets ? moveEach(extend: true) { super.moveRight(sender) } : super.moveRightAndModifySelection(sender)
    }
    override func moveUpAndModifySelection(_ sender: Any?) {
        hasMultipleCarets ? moveEach(extend: true) { super.moveUp(sender) } : super.moveUpAndModifySelection(sender)
    }
    override func moveDownAndModifySelection(_ sender: Any?) {
        hasMultipleCarets ? moveEach(extend: true) { super.moveDown(sender) } : super.moveDownAndModifySelection(sender)
    }
    override func moveWordLeftAndModifySelection(_ sender: Any?) {
        hasMultipleCarets ? moveEach(extend: true) { super.moveWordLeft(sender) } : super.moveWordLeftAndModifySelection(sender)
    }
    override func moveWordRightAndModifySelection(_ sender: Any?) {
        hasMultipleCarets ? moveEach(extend: true) { super.moveWordRight(sender) } : super.moveWordRightAndModifySelection(sender)
    }
    override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {
        hasMultipleCarets ? moveEach(extend: true) { super.moveToRightEndOfLine(sender) } : super.moveToRightEndOfLineAndModifySelection(sender)
    }

    // MARK: Editing

    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard hasMultipleCarets, replacementRange.location == NSNotFound else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        let s = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        edit { Carets.replace($1, with: s) }
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        collapseToPrimary()
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    override func deleteForward(_ sender: Any?) {
        hasMultipleCarets ? edit(onOverlap: .union) { Carets.deleteForward($0, $1) } : super.deleteForward(sender)
    }

    /// Deletes from each empty caret to where `move` takes it (non-empty selections delete
    /// themselves).
    func deleteEach(_ move: () -> Void) {
        var targets: [Int: Int] = [:]
        settingCarets = true
        for c in carets where c.length == 0 {
            setSelectedRange(c)
            move()
            targets[c.location] = selectedRange().location
        }
        settingCarets = false
        let before = carets
        edit(onOverlap: .union) { _, sel in
            if sel.length > 0 { return Carets.replace(sel, with: "") }
            guard let t = targets[sel.location], t != sel.location else { return nil }
            return Carets.replace(NSRange(location: min(t, sel.location), length: abs(t - sel.location)), with: "")
        }
        if carets == before { setCarets(before) }
    }

    override func deleteWordBackward(_ sender: Any?) {
        hasMultipleCarets ? deleteEach { super.moveWordLeft(sender) } : super.deleteWordBackward(sender)
    }
    override func deleteWordForward(_ sender: Any?) {
        hasMultipleCarets ? deleteEach { super.moveWordRight(sender) } : super.deleteWordForward(sender)
    }
    override func deleteToBeginningOfLine(_ sender: Any?) {
        hasMultipleCarets ? deleteEach { super.moveToLeftEndOfLine(sender) } : super.deleteToBeginningOfLine(sender)
    }
    override func deleteToEndOfLine(_ sender: Any?) {
        hasMultipleCarets ? deleteEach { super.moveToRightEndOfLine(sender) } : super.deleteToEndOfLine(sender)
    }

    // MARK: Mouse and clipboard

    /// ⌘-click adds a caret, or removes the one clicked.
    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command, event.clickCount == 1 else {
            super.mouseDown(with: event)
            return
        }
        window?.makeFirstResponder(self)
        let index = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        setCarets(Carets.toggle(selections, at: index))
    }

    override func copy(_ sender: Any?) {
        guard hasMultipleCarets, let text = Carets.copyText(string, carets) else { super.copy(sender); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    override func cut(_ sender: Any?) {
        guard hasMultipleCarets, let text = Carets.copyText(string, carets) else { super.cut(sender); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        edit(onOverlap: .union) { $1.length > 0 ? Carets.replace($1, with: "") : nil }
    }

    override func paste(_ sender: Any?) {
        hasMultipleCarets ? paste(transforming: { $0 }) : super.paste(sender)
    }
}
