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

    /// What `perSelection` does when two selections' edits overlap.
    public enum Overlap {
        /// Merge the two selections into their span and run the op once on it (↩, ⌘↩).
        case rerun
        /// The op only deletes: delete the union of the two ranges, caret at its start (⌫, ⌥⌫).
        case union
    }

    /// Runs `op` at every selection of `text` and composes the results into one edit; nil = no op
    /// changed anything.
    ///
    /// Each `TextEdit.selection` is in the coordinates of that edit alone, so its final position is
    /// shifted by the length change of every edit ordered before it. Edits starting at the same
    /// point order the shorter range first, so an insertion at a caret precedes a replacement of
    /// the selection that starts there.
    public static func perSelection(_ text: String, _ selections: [NSRange], onOverlap: Overlap = .rerun,
                                    _ op: (NSRange) -> TextEdit?) -> MultiEdit? {
        var items = normalize(selections).map { (sel: $0, edit: op($0)) }
        func ordered() -> [Int] {
            items.indices.filter { items[$0].edit != nil }.sorted {
                let a = items[$0].edit!.range, b = items[$1].edit!.range
                return (a.location, a.length) < (b.location, b.length)
            }
        }
        func firstOverlap() -> (Int, Int)? {
            let order = ordered()
            for (a, b) in zip(order, order.dropFirst()) {
                let ra = items[a].edit!.range, rb = items[b].edit!.range
                if rb.location < NSMaxRange(ra) || (ra.length == 0 && rb.length == 0 && ra.location == rb.location) { return (a, b) }
            }
            return nil
        }
        while let (a, b) = firstOverlap() {
            switch onOverlap {
            case .rerun:
                let lo = min(items[a].sel.location, items[b].sel.location)
                let hi = max(NSMaxRange(items[a].sel), NSMaxRange(items[b].sel))
                let rest = items.indices.filter { $0 != a && $0 != b }.map { items[$0].sel }
                items = normalize(rest + [NSRange(location: lo, length: hi - lo)]).map { ($0, op($0)) }
            case .union:
                let ra = items[a].edit!.range, rb = items[b].edit!.range
                let union = NSRange(location: min(ra.location, rb.location),
                                    length: max(NSMaxRange(ra), NSMaxRange(rb)) - min(ra.location, rb.location))
                items[a].edit = TextEdit(range: union, replacement: "", selection: NSRange(location: union.location, length: 0))
                items.remove(at: b)
            }
        }

        let order = ordered()
        guard !order.isEmpty else { return nil }
        func delta(_ i: Int) -> Int { (items[i].edit!.replacement as NSString).length - items[i].edit!.range.length }
        let finals = items.indices.map { i -> NSRange in
            if let edit = items[i].edit {
                let before = order.prefix { $0 != i }.reduce(0) { $0 + delta($1) }
                return NSRange(location: edit.selection.location + before, length: edit.selection.length)
            }
            let sel = items[i].sel
            let before = order.filter { items[$0].edit!.range.location < sel.location }.reduce(0) { $0 + delta($1) }
            return NSRange(location: sel.location + before, length: sel.length)
        }
        return MultiEdit(splices: order.map { Splice(range: items[$0].edit!.range, replacement: items[$0].edit!.replacement) },
                         selections: normalize(finals))
    }
}
