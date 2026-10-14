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

    public static func indent(_ text: String, selection sel: NSRange, unit: String) -> TextEdit {
        let t = LineTable(text), r = t.lines(covering: sel)
        let lines = r.map(t.content)
        let replacement = lines.map { $0.isEmpty ? $0 : unit + $0 }.joined(separator: "\n")
        let span = t.span(r.lowerBound, r.upperBound)
        let selection = sel.length == 0
            ? NSRange(location: sel.location + (lines[0].isEmpty ? 0 : length(unit)), length: 0)
            : NSRange(location: span.location, length: length(replacement))
        return TextEdit(range: span, replacement: replacement, selection: selection)
    }

    public static func outdent(_ text: String, selection sel: NSRange, width: Int) -> TextEdit {
        let t = LineTable(text), r = t.lines(covering: sel)
        let results = r.map { i -> (String, Int) in
            let line = t.content(i)
            if line.hasPrefix("\t") { return (String(line.dropFirst()), 1) }
            let n = min(width, line.prefix(while: { $0 == " " }).count)
            return (String(line.dropFirst(n)), n)
        }
        let replacement = results.map(\.0).joined(separator: "\n")
        let span = t.span(r.lowerBound, r.upperBound)
        let selection = sel.length == 0
            ? NSRange(location: max(t.starts[r.lowerBound], sel.location - results[0].1), length: 0)
            : NSRange(location: span.location, length: length(replacement))
        return TextEdit(range: span, replacement: replacement, selection: selection)
    }

    public static func moveUp(_ text: String, selection sel: NSRange) -> TextEdit? {
        let t = LineTable(text), r = t.lines(covering: sel)
        guard r.lowerBound > 0 else { return nil }
        let above = t.content(r.lowerBound - 1)
        let replacement = (r.map(t.content) + [above]).joined(separator: "\n")
        return TextEdit(range: t.span(r.lowerBound - 1, r.upperBound), replacement: replacement,
                        selection: NSRange(location: sel.location - length(above) - 1, length: sel.length))
    }

    public static func moveDown(_ text: String, selection sel: NSRange) -> TextEdit? {
        let t = LineTable(text), r = t.lines(covering: sel)
        guard r.upperBound < t.count - 1 else { return nil }
        let below = t.content(r.upperBound + 1)
        let replacement = ([below] + r.map(t.content)).joined(separator: "\n")
        return TextEdit(range: t.span(r.lowerBound, r.upperBound + 1), replacement: replacement,
                        selection: NSRange(location: sel.location + length(below) + 1, length: sel.length))
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
