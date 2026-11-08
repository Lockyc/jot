import Foundation

/// One replacement, in the coordinates of the text before any splice of its edit is applied.
public struct Splice: Equatable {
    public var range: NSRange
    public var replacement: String

    public init(range: NSRange, replacement: String) {
        self.range = range
        self.replacement = replacement
    }
}

/// An edit at every caret, applied as one change: `splices` ascending and non-overlapping in the
/// original text's coordinates, `selections` normalized in the edited text's coordinates.
public struct MultiEdit: Equatable {
    public var splices: [Splice]
    public var selections: [NSRange]

    public init(splices: [Splice], selections: [NSRange]) {
        self.splices = splices
        self.selections = selections
    }

    public func applied(to text: String) -> String {
        let s = NSMutableString(string: text)
        for sp in splices.reversed() { s.replaceCharacters(in: sp.range, with: sp.replacement) }
        return s as String
    }

    /// Sorted by location; overlapping or duplicate ranges merge, and a caret strictly inside a
    /// selection is absorbed by it. Distinct carets, and a caret at a selection's edge, stay apart.
    public static func normalize(_ selections: [NSRange]) -> [NSRange] {
        var out: [NSRange] = []
        for s in selections.sorted(by: { ($0.location, $0.length) < ($1.location, $1.length) }) {
            guard let last = out.last else { out.append(s); continue }
            if s == last { continue }
            let lastEnd = NSMaxRange(last)
            let overlaps = s.location < lastEnd && (s.length > 0 || last.length > 0)
            if overlaps {
                out[out.count - 1] = NSRange(location: last.location, length: max(lastEnd, NSMaxRange(s)) - last.location)
            } else {
                out.append(s)
            }
        }
        return out
    }

    /// Runs `op` at every selection of `text` and composes the results. Selections whose edits
    /// overlap merge into their union span and `op` runs once on it. nil = no op changed anything.
    ///
    /// Each `TextEdit.selection` is in the coordinates of that edit alone, so its final position is
    /// shifted by the length change of every edit before it.
    public static func perSelection(_ text: String, _ selections: [NSRange], _ op: (NSRange) -> TextEdit?) -> MultiEdit? {
        var sels = normalize(selections)
        var edits: [(sel: NSRange, edit: TextEdit?)]
        while true {
            edits = sels.map { ($0, op($0)) }
            let changing = edits.indices.filter { edits[$0].edit != nil }
                .sorted { edits[$0].edit!.range.location < edits[$1].edit!.range.location }
            var conflict: (Int, Int)?
            for (a, b) in zip(changing, changing.dropFirst()) {
                let ra = edits[a].edit!.range, rb = edits[b].edit!.range
                let overlap = rb.location < NSMaxRange(ra) || (ra.length == 0 && rb.length == 0 && ra.location == rb.location)
                if overlap { conflict = (a, b); break }
            }
            guard let (a, b) = conflict else { break }
            let lo = min(sels[a].location, sels[b].location)
            let hi = max(NSMaxRange(sels[a]), NSMaxRange(sels[b]))
            let merged = NSRange(location: lo, length: hi - lo)
            sels = normalize(sels.enumerated().filter { $0.offset != a && $0.offset != b }.map(\.element) + [merged])
        }

        let changing = edits.compactMap(\.edit).sorted { $0.range.location < $1.range.location }
        guard !changing.isEmpty else { return nil }
        func delta(_ e: TextEdit) -> Int { (e.replacement as NSString).length - e.range.length }

        var finals: [NSRange] = []
        for (sel, edit) in edits {
            if let edit {
                let before = changing.prefix { $0.range.location < edit.range.location }.reduce(0) { $0 + delta($1) }
                finals.append(NSRange(location: edit.selection.location + before, length: edit.selection.length))
            } else {
                let before = changing.prefix { $0.range.location < sel.location }.reduce(0) { $0 + delta($1) }
                finals.append(NSRange(location: sel.location + before, length: sel.length))
            }
        }
        return MultiEdit(splices: changing.map { Splice(range: $0.range, replacement: $0.replacement) },
                         selections: normalize(finals))
    }
}
