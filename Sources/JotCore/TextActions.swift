import Foundation

public enum TextActions {
    static let boxMarkers: Set<Character> = ["│", "┃", "▎", "▌", "⎿"]
    static let asciiMarkers: Set<Character> = ["|", ">"]

    static func isIndent(_ c: Character) -> Bool { c == " " || c == "\t" }
    static func isBlank<S: StringProtocol>(_ line: S) -> Bool { line.allSatisfy(isIndent) }

    /// Splits on LF or CRLF; when the text ends with a newline the trailing empty line is held
    /// back from `f` and restored, so line transforms never sort or number it.
    static func transformLines(_ s: String, _ f: ([String]) -> [String]) -> String {
        var lines = s.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" })
            .map(String.init)
        let trailingNewline = lines.count > 1 && lines.last == ""
        if trailingNewline { lines.removeLast() }
        var out = f(lines)
        if trailingNewline { out.append("") }
        return out.joined(separator: "\n")
    }

    /// Removes one leading gutter marker (plus one following space) per line, then dedents.
    /// When any line leads with a box-drawing marker, only box markers count as gutter — so `|`
    /// and `>` inside a Claude-quoted block (markdown tables, quotes) survive.
    public static func stripQuoteGutter(_ s: String) -> String {
        let leading = transformLines(s) { $0 }.split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { $0.first(where: { !isIndent($0) }) }
        let markers = leading.contains(where: boxMarkers.contains) ? boxMarkers : asciiMarkers
        let stripped = transformLines(s) { lines in
            lines.map { line in
                let afterIndent = line.drop(while: isIndent)
                guard let first = afterIndent.first, markers.contains(first) else { return line }
                var rest = afterIndent.dropFirst()
                if rest.first == " " { rest = rest.dropFirst() }
                return String(rest)
            }
        }
        return dedent(stripped)
    }

    /// The longest leading-whitespace prefix shared by every non-blank line; nil when all are blank.
    static func commonIndent<C: Collection>(_ lines: C) -> String? where C.Element == String {
        let indents = lines.filter { !isBlank($0) }.map { String($0.prefix(while: isIndent)) }
        guard var common = indents.first else { return nil }
        for indent in indents.dropFirst() {
            common = String(zip(common, indent).prefix(while: { $0 == $1 }).map(\.0))
        }
        return common
    }

    /// Removes the longest leading-whitespace prefix shared by every non-blank line;
    /// whitespace-only lines come out empty.
    public static func dedent(_ s: String) -> String {
        transformLines(s) { lines in
            guard let common = commonIndent(lines) else { return lines.map { _ in "" } }
            return lines.map { isBlank($0) ? "" : String($0.dropFirst(common.count)) }
        }
    }

    /// Narrower than any terminal Claude Code is usable in, so a run of short lines never reads
    /// as wrapped just because its own widest line is short.
    static let minimumWrapWidth = 40

    /// Rejoins lines a terminal app hard-wrapped at its width, as Claude Code does: a line joins
    /// the one above when its first word would not have fitted on that line — the wrap condition
    /// itself, with the widest line standing in for the terminal width. Blank lines, list items,
    /// headings, quotes, table rows, box-drawn lines and fenced code are never joined. Drops the
    /// `⏺` reply marker and dedents, treating a first line indented less than the rest as one
    /// whose margin the selection cut off.
    public static func unwrap(_ s: String) -> String {
        transformLines(s) { input in
            var lines = input.map { String($0.reversed().drop(while: isIndent).reversed()) }
            if let i = lines.first?.firstIndex(where: { !isIndent($0) }), lines[0][i] == "⏺" {
                lines[0].replaceSubrange(i...i, with: " ")
            }
            let indent = { (line: String) in line.prefix(while: isIndent).count }
            let cutMargin = lines.count > 1 ? max(0, indent(lines[1]) - indent(lines[0])) : 0
            let measured = lines.indices.map { lines[$0].count + ($0 == 0 ? cutMargin : 0) }
            let width = max(minimumWrapWidth, measured.max() ?? 0)

            var out: [String] = []
            var inFence = false
            for (i, line) in lines.enumerated() {
                let body = line.drop(while: isIndent)
                let fence = body.hasPrefix("```") || body.hasPrefix("~~~")
                if fence { inFence.toggle() }
                let joins = i > 0 && !fence && !inFence && !body.isEmpty && !isBlank(lines[i - 1])
                    && !startsBlock(body) && !isRigid(lines[i - 1].drop(while: isIndent))
                    && measured[i - 1] + 1 + body.prefix(while: { $0 != " " }).count > width
                if joins { out[out.count - 1] += " " + body } else { out.append(line) }
            }

            let common = commonIndent(out.dropFirst()) ?? out.first.map { String($0.prefix(while: isIndent)) } ?? ""
            return out.enumerated().map { i, line in
                if isBlank(line) { return "" }
                return String(i == 0 ? line.dropFirst(min(common.count, indent(line))) : line.dropFirst(common.count))
            }
        }
    }

    /// A line that opens its own block in rendered markdown, so it never continues the one above.
    static func startsBlock(_ body: Substring) -> Bool {
        LineOps.listMarker(body) != nil || body.hasPrefix("• ") || body.hasPrefix("+ ")
            || body.hasPrefix("#") || body.hasPrefix(">") || isRigid(body)
    }

    /// A table row or box-drawn line: laid out by column, so nothing joins onto it either.
    static func isRigid(_ body: Substring) -> Bool {
        guard let c = body.unicodeScalars.first else { return false }
        return c == "|" || (0x2500...0x259F).contains(c.value) || boxMarkers.contains(Character(c))
    }

    public static func trimTrailingWhitespace(_ s: String) -> String {
        transformLines(s) { lines in
            lines.map { line in
                var l = line
                while let c = l.last, isIndent(c) { l.removeLast() }
                return l
            }
        }
    }

    public static func sortLines(_ s: String, descending: Bool) -> String {
        transformLines(s) { lines in
            lines.sorted {
                let order = $0.localizedStandardCompare($1)
                return descending ? order == .orderedDescending : order == .orderedAscending
            }
        }
    }

    public static func removeDuplicateLines(_ s: String) -> String {
        transformLines(s) { lines in
            var seen = Set<String>()
            return lines.filter { seen.insert($0).inserted }
        }
    }

    public static func removeBlankLines(_ s: String) -> String {
        transformLines(s) { lines in lines.filter { !isBlank($0) } }
    }

    public static func joinLines(_ s: String) -> String {
        transformLines(s) { lines in
            [lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")]
        }
    }

    public static func split(_ s: String, on delimiter: String) -> String {
        guard !delimiter.isEmpty else { return s }
        return s.components(separatedBy: delimiter)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    public static func uppercase(_ s: String) -> String { s.uppercased() }
    public static func lowercase(_ s: String) -> String { s.lowercased() }
    public static func titleCase(_ s: String) -> String { s.capitalized }

    public static func numberLines(_ s: String) -> String {
        transformLines(s) { lines in
            var n = 0
            return lines.map { line in
                guard !isBlank(line) else { return line }
                n += 1
                return "\(n). \(line)"
            }
        }
    }
}
