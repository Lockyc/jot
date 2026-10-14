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
}
