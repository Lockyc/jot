import Foundation

/// Per-caret editing primitives and the caret-list operations behind multi-cursor editing.
public enum Carets {
    /// Typing or pasting `s` over the selection; the caret lands after it.
    public static func replace(_ sel: NSRange, with s: String) -> TextEdit {
        TextEdit(range: sel, replacement: s, selection: NSRange(location: sel.location + (s as NSString).length, length: 0))
    }

    static func delete(_ range: NSRange) -> TextEdit {
        TextEdit(range: range, replacement: "", selection: NSRange(location: range.location, length: 0))
    }

    /// ⌫: the selection, else the smart indent stop, else the composed character before the caret.
    public static func deleteBackward(_ text: String, _ sel: NSRange, indentWidth: Int) -> TextEdit? {
        if sel.length > 0 { return delete(sel) }
        if let smart = LineOps.deleteBackward(text, selection: sel, width: indentWidth) { return smart }
        guard sel.location > 0 else { return nil }
        return delete((text as NSString).rangeOfComposedCharacterSequence(at: sel.location - 1))
    }

    /// ⌦: the selection, else the composed character after the caret.
    public static func deleteForward(_ text: String, _ sel: NSRange) -> TextEdit? {
        if sel.length > 0 { return delete(sel) }
        let ns = text as NSString
        guard sel.location < ns.length else { return nil }
        return delete(ns.rangeOfComposedCharacterSequence(at: sel.location))
    }

    /// ⇧⌘L: a caret at the end of every line each non-empty selection covers. Empty carets stay.
    public static func splitIntoLines(_ text: String, _ sels: [NSRange]) -> [NSRange] {
        let t = LineTable(text)
        return MultiEdit.normalize(sels.flatMap { s -> [NSRange] in
            guard s.length > 0 else { return [s] }
            let lines = t.lines(covering: s)
            return lines.map { NSRange(location: $0 == lines.upperBound ? min(t.end($0), NSMaxRange(s)) : t.end($0), length: 0) }
        })
    }

    /// ⌃⇧↑/⌃⇧↓: a caret on the line beyond the topmost selection's first line (the bottommost's
    /// last line), at that end's column clamped to the line's length and snapped back to a
    /// character boundary. Unchanged at the first (last) line.
    public static func addVertical(_ text: String, _ sels: [NSRange], up: Bool) -> [NSRange] {
        let t = LineTable(text), sorted = MultiEdit.normalize(sels)
        guard let edge = up ? sorted.first : sorted.last else { return sels }
        let line = up ? t.line(at: edge.location) : t.lines(covering: edge).upperBound
        let target = up ? line - 1 : line + 1
        guard target >= 0, target < t.count else { return sorted }
        let column = min(up ? edge.location : NSMaxRange(edge), t.end(line)) - t.starts[line]
        var location = min(t.starts[target] + column, t.end(target))
        if location < t.end(target) { location = t.ns.rangeOfComposedCharacterSequence(at: location).location }
        return MultiEdit.normalize(sorted + [NSRange(location: location, length: 0)])
    }

    /// ⌘-click: adds an empty caret at `location`, or removes the one there — never the last.
    public static func toggle(_ sels: [NSRange], at location: Int) -> [NSRange] {
        let caret = NSRange(location: location, length: 0)
        if sels.contains(caret) {
            return sels.count > 1 ? sels.filter { $0 != caret } : sels
        }
        return MultiEdit.normalize(sels + [caret])
    }

    /// Paste: with several selections and exactly as many clipboard lines (one trailing newline
    /// ignored), line *i* goes into selection *i*; otherwise the whole clipboard into each.
    public static func paste(_ text: String, _ sels: [NSRange], clipboard: String) -> MultiEdit? {
        let sorted = MultiEdit.normalize(sels)
        let body = clipboard.hasSuffix("\n") ? String(clipboard.dropLast()) : clipboard
        let lines = body.components(separatedBy: "\n")
        guard sorted.count > 1, lines.count == sorted.count else {
            return MultiEdit.perSelection(text, sorted) { replace($0, with: clipboard) }
        }
        return MultiEdit.perSelection(text, sorted) { s in replace(s, with: sorted.firstIndex(of: s).map { lines[$0] } ?? clipboard) }
    }

    /// Copy: the non-empty selections joined with newlines; nil when every selection is empty.
    public static func copyText(_ text: String, _ sels: [NSRange]) -> String? {
        let ns = text as NSString
        let parts = MultiEdit.normalize(sels).filter { $0.length > 0 }.map(ns.substring(with:))
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
}
