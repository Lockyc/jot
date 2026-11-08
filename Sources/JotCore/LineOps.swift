import Foundation

public struct TextEdit: Equatable {
    public var range: NSRange
    public var replacement: String
    public var selection: NSRange

    public init(range: NSRange, replacement: String, selection: NSRange) {
        self.range = range
        self.replacement = replacement
        self.selection = selection
    }
}

/// Line starts of a text in UTF-16 offsets — the unit NSTextView ranges use.
struct LineTable {
    let ns: NSString
    let starts: [Int]

    init(_ text: String) {
        ns = text as NSString
        var s = [0]
        for i in 0..<ns.length where ns.character(at: i) == 0x0A { s.append(i + 1) }
        starts = s
    }

    var count: Int { starts.count }

    func line(at location: Int) -> Int {
        var lo = 0, hi = starts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if starts[mid] <= location { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    /// End of line `i`'s content, excluding its newline.
    func end(_ i: Int) -> Int { i + 1 < starts.count ? starts[i + 1] - 1 : ns.length }
    func content(_ i: Int) -> String { ns.substring(with: NSRange(location: starts[i], length: end(i) - starts[i])) }
    func span(_ a: Int, _ b: Int) -> NSRange { NSRange(location: starts[a], length: end(b) - starts[a]) }

    /// Lines touched by `sel`; a non-empty selection ending exactly at a line start excludes that line.
    func lines(covering sel: NSRange) -> ClosedRange<Int> {
        let first = line(at: sel.location)
        var endLocation = sel.location + sel.length
        if sel.length > 0, endLocation > starts[first], starts[line(at: endLocation)] == endLocation {
            endLocation -= 1
        }
        return first...line(at: endLocation)
    }
}

public enum LineOps {
    static func length(_ s: String) -> Int { (s as NSString).length }

    /// Blocks of contiguous lines the selections touch; lines next to each other join one block.
    static func blocks(_ t: LineTable, _ sels: [NSRange]) -> [ClosedRange<Int>] {
        var blocks: [ClosedRange<Int>] = []
        for r in sels.map(t.lines(covering:)).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = blocks.last, r.lowerBound <= last.upperBound + 1 {
                blocks[blocks.count - 1] = last.lowerBound...max(last.upperBound, r.upperBound)
            } else {
                blocks.append(r)
            }
        }
        return blocks
    }

    /// A per-line edit at the start of every line the selections touch: `cut(line)` is how many
    /// leading characters to remove, `insert(line)` what to put there. Carets move with their
    /// line's edit; a non-empty selection becomes its whole lines.
    static func lineStarts(_ text: String, _ selections: [NSRange], cut: (String) -> Int, insert: (String) -> String) -> MultiEdit? {
        let t = LineTable(text), sels = MultiEdit.normalize(selections)
        let lines = Set(sels.flatMap { Array(t.lines(covering: $0)) }).sorted()
        let edits = lines.compactMap { i -> (line: Int, splice: Splice)? in
            let content = t.content(i), n = cut(content), s = insert(content)
            return n == 0 && s.isEmpty ? nil : (i, Splice(range: NSRange(location: t.starts[i], length: n), replacement: s))
        }
        guard !edits.isEmpty else { return nil }
        func delta(_ e: (line: Int, splice: Splice)) -> Int { length(e.splice.replacement) - e.splice.range.length }
        /// Where `location` on `line` lands: after every edit on earlier lines and, for its own line,
        /// after the insert, clamped to the line start when it sat in the removed characters.
        func map(_ location: Int, line: Int) -> Int {
            let before = edits.filter { $0.line < line }.reduce(0) { $0 + delta($1) }
            guard let own = edits.first(where: { $0.line == line })?.splice else { return location + before }
            let start = t.starts[line] + before
            return start + length(own.replacement) + max(0, location - t.starts[line] - own.range.length)
        }
        let mapped = sels.map { s -> NSRange in
            guard s.length > 0 else { return NSRange(location: map(s.location, line: t.line(at: s.location)), length: 0) }
            let r = t.lines(covering: s)
            let start = t.starts[r.lowerBound] + edits.filter { $0.line < r.lowerBound }.reduce(0) { $0 + delta($1) }
            let end = t.end(r.upperBound) + edits.filter { $0.line <= r.upperBound }.reduce(0) { $0 + delta($1) }
            return NSRange(location: start, length: end - start)
        }
        return MultiEdit(splices: edits.map(\.splice), selections: mapped)
    }

    /// ⇥ on a selection / ⌘]: the indent unit before every non-empty line the selections touch.
    public static func indent(_ text: String, selections: [NSRange], unit: String) -> MultiEdit? {
        lineStarts(text, selections, cut: { _ in 0 }, insert: { $0.isEmpty ? "" : unit })
    }

    /// ⇧⇥ / ⌘[: one leading tab, or up to `width` leading spaces, off every line the selections touch.
    public static func outdent(_ text: String, selections: [NSRange], width: Int) -> MultiEdit? {
        lineStarts(text, selections, cut: { line in
            line.hasPrefix("\t") ? 1 : min(width, line.prefix(while: { $0 == " " }).count)
        }, insert: { _ in "" })
    }

    /// ⌥↑/⌥↓: every block of contiguous lines the selections touch swaps with the line beyond it,
    /// carrying its selections. nil when any block is already at the edge.
    public static func move(_ text: String, selections: [NSRange], up: Bool) -> MultiEdit? {
        let t = LineTable(text), sels = MultiEdit.normalize(selections)
        guard !sels.isEmpty else { return nil }
        let blocks = blocks(t, sels)
        guard up ? blocks[0].lowerBound > 0 : blocks[blocks.count - 1].upperBound < t.count - 1 else { return nil }
        let splices = blocks.map { b -> Splice in
            let lines = b.map(t.content)
            return up
                ? Splice(range: t.span(b.lowerBound - 1, b.upperBound), replacement: (lines + [t.content(b.lowerBound - 1)]).joined(separator: "\n"))
                : Splice(range: t.span(b.lowerBound, b.upperBound + 1), replacement: ([t.content(b.upperBound + 1)] + lines).joined(separator: "\n"))
        }
        let moved = sels.map { s -> NSRange in
            let b = blocks.first { $0.contains(t.line(at: s.location)) }!
            let shift = up ? -(length(t.content(b.lowerBound - 1)) + 1) : length(t.content(b.upperBound + 1)) + 1
            return NSRange(location: s.location + shift, length: s.length)
        }
        return MultiEdit(splices: splices, selections: moved)
    }

    public static func duplicate(_ text: String, selection sel: NSRange) -> TextEdit {
        let t = LineTable(text)
        if sel.length > 0 {
            let copy = t.ns.substring(with: sel)
            return TextEdit(range: NSRange(location: NSMaxRange(sel), length: 0), replacement: copy,
                            selection: NSRange(location: NSMaxRange(sel), length: sel.length))
        }
        let r = t.lines(covering: sel), span = t.span(r.lowerBound, r.upperBound)
        let block = t.ns.substring(with: span)
        return TextEdit(range: NSRange(location: NSMaxRange(span), length: 0), replacement: "\n" + block,
                        selection: NSRange(location: sel.location + length(block) + 1, length: 0))
    }

    /// ⌘D: with only carets, each line holding one is duplicated once and its carets move onto the
    /// copy; otherwise each non-empty selection duplicates itself and carets stay put.
    public static func duplicate(_ text: String, selections: [NSRange]) -> MultiEdit? {
        let sels = MultiEdit.normalize(selections)
        guard sels.allSatisfy({ $0.length == 0 }) else {
            return MultiEdit.perSelection(text, sels) { $0.length > 0 ? duplicate(text, selection: $0) : nil }
        }
        let t = LineTable(text)
        let lines = Set(sels.map { t.line(at: $0.location) }).sorted()
        func grown(_ line: Int) -> Int { length(t.content(line)) + 1 }
        let carets = sels.map { s -> NSRange in
            let line = t.line(at: s.location)
            let before = lines.filter { $0 < line }.reduce(0) { $0 + grown($1) }
            return NSRange(location: s.location + before + grown(line), length: 0)
        }
        return MultiEdit(splices: lines.map { Splice(range: NSRange(location: t.end($0), length: 0), replacement: "\n" + t.content($0)) },
                         selections: carets)
    }

    /// ⇧⌘K: every block of contiguous touched lines is removed, one caret left per block.
    public static func deleteLines(_ text: String, selections: [NSRange]) -> MultiEdit? {
        let t = LineTable(text)
        let spans = blocks(t, MultiEdit.normalize(selections)).map { t.span($0.lowerBound, $0.upperBound) }
        return MultiEdit.perSelection(text, spans) { deleteLines(text, selection: $0) }
    }

    /// The list marker opening `s` (`- `, `* `, `3. `, `3) `) and the one the next item takes.
    static func listMarker(_ s: Substring) -> (current: String, next: String)? {
        for bullet in ["- ", "* "] where s.hasPrefix(bullet) { return (bullet, bullet) }
        let digits = s.prefix(while: \.isASCII).prefix(while: \.isNumber)
        guard (1...9).contains(digits.count), let n = Int(digits) else { return nil }
        let rest = s.dropFirst(digits.count)
        guard let delimiter = [". ", ") "].first(where: { rest.hasPrefix($0) }) else { return nil }
        return (digits + delimiter, "\(n + 1)" + delimiter)
    }

    /// What a new line after `caret` starts with: the indent before the caret, plus the next
    /// list marker when the caret is past one.
    static func continuation(_ t: LineTable, line: Int, caret: Int) -> (indent: String, marker: (current: String, next: String)?) {
        let before = t.ns.substring(with: NSRange(location: t.starts[line], length: caret - t.starts[line]))
        let indent = String(before.prefix(while: { $0 == " " || $0 == "\t" }))
        return (indent, listMarker(before.dropFirst(indent.count)))
    }

    /// Return: carry the line's indent and list marker onto the new line. Return on a list item
    /// with nothing after its marker ends the list, leaving the line blank.
    public static func newline(_ text: String, selection sel: NSRange) -> TextEdit {
        let t = LineTable(text), line = t.line(at: sel.location)
        let (indent, marker) = continuation(t, line: line, caret: sel.location)
        if let marker, sel.length == 0,
           t.content(line).trimmingCharacters(in: .whitespaces) == marker.current.trimmingCharacters(in: .whitespaces) {
            let span = t.span(line, line)
            return TextEdit(range: span, replacement: "", selection: NSRange(location: span.location, length: 0))
        }
        let insert = "\n" + indent + (marker?.next ?? "")
        return TextEdit(range: sel, replacement: insert, selection: NSRange(location: sel.location + length(insert), length: 0))
    }

    /// ⌘↩: a new line below the last selected line, with that line's indent and next list marker.
    public static func insertLineBelow(_ text: String, selection sel: NSRange) -> TextEdit {
        let t = LineTable(text), line = t.lines(covering: sel).upperBound, end = t.end(line)
        let (indent, marker) = continuation(t, line: line, caret: end)
        let insert = "\n" + indent + (marker?.next ?? "")
        return TextEdit(range: NSRange(location: end, length: 0), replacement: insert,
                        selection: NSRange(location: end + length(insert), length: 0))
    }

    /// Backspace with the caret in a line's leading spaces deletes back to the previous indent
    /// stop. nil = not in leading spaces; the native delete applies.
    public static func deleteBackward(_ text: String, selection sel: NSRange, width: Int) -> TextEdit? {
        guard sel.length == 0, width > 0 else { return nil }
        let t = LineTable(text), start = t.starts[t.line(at: sel.location)], column = sel.location - start
        guard column > 0, t.ns.substring(with: NSRange(location: start, length: column)).allSatisfy({ $0 == " " }) else { return nil }
        let stop = (column - 1) / width * width
        return TextEdit(range: NSRange(location: start + stop, length: column - stop), replacement: "",
                        selection: NSRange(location: start + stop, length: 0))
    }

    /// ⌘←: the line's first non-blank character, or column 0 when already there.
    public static func smartLineStart(_ text: String, caret: Int) -> Int {
        let t = LineTable(text), line = t.line(at: caret), start = t.starts[line]
        let first = start + length(String(t.content(line).prefix(while: { $0 == " " || $0 == "\t" })))
        return first == t.end(line) || caret == first ? start : first
    }

    /// ⇧⌘K: removes every line the selection touches, with one adjoining newline.
    public static func deleteLines(_ text: String, selection sel: NSRange) -> TextEdit {
        let t = LineTable(text), r = t.lines(covering: sel)
        let range: NSRange, caret: Int
        if r.upperBound + 1 < t.count {
            range = NSRange(location: t.starts[r.lowerBound], length: t.starts[r.upperBound + 1] - t.starts[r.lowerBound])
            caret = t.starts[r.lowerBound]
        } else if r.lowerBound > 0 {
            range = NSRange(location: t.starts[r.lowerBound] - 1, length: t.ns.length - t.starts[r.lowerBound] + 1)
            caret = t.starts[r.lowerBound - 1]
        } else {
            range = NSRange(location: 0, length: t.ns.length)
            caret = 0
        }
        return TextEdit(range: range, replacement: "", selection: NSRange(location: caret, length: 0))
    }

    /// Whole lines under the selection, newline included; repeating on an exact line selection
    /// extends it by the next line.
    public static func selectLine(_ text: String, selection sel: NSRange) -> NSRange {
        let t = LineTable(text), r = t.lines(covering: sel)
        func full(_ a: Int, _ b: Int) -> NSRange {
            let end = b + 1 < t.count ? t.starts[b + 1] : t.ns.length
            return NSRange(location: t.starts[a], length: end - t.starts[a])
        }
        let current = full(r.lowerBound, r.upperBound)
        if sel == current, r.upperBound + 1 < t.count { return full(r.lowerBound, r.upperBound + 1) }
        return current
    }
}
