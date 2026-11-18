import Foundation
import PropertyBased
import Testing
@testable import JotCore

/// Generated texts mix ASCII, list markers, tabs, newlines, a precomposed accent and surrogate
/// pairs; selections are 1 to 5 ranges snapped to composed-character boundaries, as NSTextView
/// hands them over.
enum MultiCaretGen {
    static let tokens = ["a", "b", "x", " ", "  ", "\t", "\n", "\n", "👍", "é", "- ", "1. ", "🇦🇺"]
    static let input = zip(
        Gen.element(of: tokens).array(of: 0...24),
        Gen.int(in: 0...10_000).array(of: 5),
        Gen.int(in: 0...8).array(of: 5),
        Gen.int(in: 1...5)
    ).map { parts, locations, lengths, count -> Sample in
        let text = parts.compactMap { $0 }.joined()
        return Sample(text: text, selections: (0..<count).map { snap(text, locations[$0], lengths[$0]) })
    }

    struct Sample: CustomStringConvertible {
        let text: String
        let selections: [NSRange]
        var description: String { "text: \(text.debugDescription) selections: \(selections)" }
    }

    static func boundary(_ ns: NSString, _ location: Int) -> Int {
        location >= ns.length ? ns.length : ns.rangeOfComposedCharacterSequence(at: location).location
    }

    static func snap(_ text: String, _ location: Int, _ length: Int) -> NSRange {
        let ns = text as NSString
        let start = boundary(ns, location % (ns.length + 1))
        let end = boundary(ns, min(ns.length, start + length))
        return NSRange(location: start, length: max(0, end - start))
    }

    static func isBoundary(_ text: String, _ location: Int) -> Bool {
        let ns = text as NSString
        return location == ns.length || (location < ns.length && ns.rangeOfComposedCharacterSequence(at: location).location == location)
    }
}

/// One per-caret op from the editor, with the overlap policy `EditorView` runs it under.
struct CaretOp: CustomStringConvertible, Sendable {
    let name: String
    let deletesOnly: Bool
    let run: @Sendable (String, NSRange) -> TextEdit?
    var description: String { name }
    var overlap: MultiEdit.Overlap { deletesOnly ? .union : .rerun }

    static let all: [CaretOp] = [
        CaretOp(name: "type", deletesOnly: false) { _, s in Carets.replace(s, with: "Z") },
        CaretOp(name: "⌫", deletesOnly: true) { t, s in Carets.deleteBackward(t, s, indentWidth: 4) },
        CaretOp(name: "⌦", deletesOnly: true) { t, s in Carets.deleteForward(t, s) },
        CaretOp(name: "↩", deletesOnly: false) { t, s in LineOps.newline(t, selection: s) },
        CaretOp(name: "⌘↩", deletesOnly: false) { t, s in LineOps.insertLineBelow(t, selection: s) },
        CaretOp(name: "⇧⌘K one", deletesOnly: false) { t, s in LineOps.deleteLines(t, selection: s) },
        CaretOp(name: "⌘D one", deletesOnly: false) { t, s in LineOps.duplicate(t, selection: s) },
    ]
}

/// The contract `MultiEdit`'s docblock states, for any edit an op produces over `text`.
func expectWellFormed(_ m: MultiEdit, over text: String, op: String, sourceLocation: SourceLocation = #_sourceLocation) {
    let length = (text as NSString).length
    for sp in m.splices {
        #expect(sp.range.location >= 0 && NSMaxRange(sp.range) <= length, "\(op): splice \(sp.range) outside the text", sourceLocation: sourceLocation)
    }
    for (a, b) in zip(m.splices, m.splices.dropFirst()) {
        let ordered = b.range.location >= NSMaxRange(a.range)
            && !(a.range.length == 0 && b.range.length == 0 && a.range.location == b.range.location)
        #expect(ordered, "\(op): splices \(a.range) and \(b.range) not ascending and non-overlapping", sourceLocation: sourceLocation)
    }
    let applied = (m.applied(to: text) as NSString).length
    for s in m.selections {
        #expect(s.location >= 0 && NSMaxRange(s) <= applied, "\(op): selection \(s) outside the edited text (\(applied))", sourceLocation: sourceLocation)
    }
    #expect(MultiEdit.normalize(m.selections) == m.selections, "\(op): selections \(m.selections) not normalized", sourceLocation: sourceLocation)
}

@Suite struct MultiCaretPropertyTests {
    @Test func addVerticalLandsOnCharacterBoundaries() async {
        await propertyCheck(count: 400, input: MultiCaretGen.input, Gen.bool) { sample, up in
            for s in Carets.addVertical(sample.text, sample.selections, up: up) {
                #expect(MultiCaretGen.isBoundary(sample.text, s.location), "\(s) splits a character")
                #expect(MultiCaretGen.isBoundary(sample.text, NSMaxRange(s)), "\(s) ends inside a character")
            }
        }
    }

    @Test(arguments: CaretOp.all) func perSelectionIsWellFormed(op: CaretOp) async {
        await propertyCheck(count: 300, input: MultiCaretGen.input) { sample in
            let text = sample.text
            guard let m = MultiEdit.perSelection(text, sample.selections, onOverlap: op.overlap, { op.run(text, $0) }) else { return }
            expectWellFormed(m, over: text, op: op.name)
        }
    }

    @Test(arguments: CaretOp.all) func oneCaretMatchesItsTextEdit(op: CaretOp) async {
        await propertyCheck(count: 300, input: MultiCaretGen.input) { sample in
            let text = sample.text, sel = sample.selections[0]
            let m = MultiEdit.perSelection(text, [sel], onOverlap: op.overlap) { op.run(text, $0) }
            guard let edit = op.run(text, sel) else {
                #expect(m == nil)
                return
            }
            let direct = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
            #expect(m?.applied(to: text) == direct)
            #expect(m?.selections == [edit.selection])
        }
    }

    @Test func lineOpsAreWellFormed() async {
        await propertyCheck(count: 300, input: MultiCaretGen.input, Gen.bool) { sample, up in
            let t = sample.text, sels = sample.selections
            let edits: [(String, MultiEdit?)] = [
                ("⌘D", LineOps.duplicate(t, selections: sels)),
                ("⇧⌘K", LineOps.deleteLines(t, selections: sels)),
                ("⌘]", LineOps.indent(t, selections: sels, unit: "\t")),
                ("⌘[", LineOps.outdent(t, selections: sels, width: 4)),
                ("⌥↑/⌥↓", LineOps.move(t, selections: sels, up: up)),
                ("paste", Carets.paste(t, sels, clipboard: "p\nq\nr")),
            ]
            for (name, m) in edits {
                guard let m else { continue }
                expectWellFormed(m, over: t, op: name)
            }
        }
    }

    /// ⌘D with carets only: every line holding a caret appears once more, right below itself.
    @Test func duplicateAddsEachCaretLineOnce() async {
        await propertyCheck(count: 400, input: MultiCaretGen.input) { sample in
            let t = sample.text, carets = sample.selections.map { NSRange(location: $0.location, length: 0) }
            let table = LineTable(t)
            let touched = Set(carets.map { table.line(at: $0.location) })
            var expected: [String] = []
            for i in 0..<table.count {
                expected.append(table.content(i))
                if touched.contains(i) { expected.append(table.content(i)) }
            }
            let m = LineOps.duplicate(t, selections: carets)
            #expect(m?.applied(to: t).components(separatedBy: "\n") == expected)
        }
    }

    /// ⇧⌘K: exactly the distinct lines the selections touch go, however many carets share them.
    @Test func deleteLinesRemovesExactlyTheTouchedLines() async {
        await propertyCheck(count: 400, input: MultiCaretGen.input) { sample in
            let t = sample.text, table = LineTable(t)
            let touched = Set(sample.selections.flatMap { Array(table.lines(covering: $0)) })
            var expected = (0..<table.count).filter { !touched.contains($0) }.map(table.content)
            if expected.isEmpty { expected = [""] }
            let m = LineOps.deleteLines(t, selections: sample.selections)
            #expect(m?.applied(to: t).components(separatedBy: "\n") == expected)
        }
    }
}
