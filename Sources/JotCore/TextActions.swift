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

    /// Removes the longest leading-whitespace prefix shared by every non-blank line;
    /// whitespace-only lines come out empty.
    public static func dedent(_ s: String) -> String {
        transformLines(s) { lines in
            let indents = lines.filter { !isBlank($0) }.map { String($0.prefix(while: isIndent)) }
            guard var common = indents.first else { return lines.map { _ in "" } }
            for indent in indents.dropFirst() {
                common = String(zip(common, indent).prefix(while: { $0 == $1 }).map(\.0))
            }
            return lines.map { isBlank($0) ? "" : String($0.dropFirst(common.count)) }
        }
    }
}
