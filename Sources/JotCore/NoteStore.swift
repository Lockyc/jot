import Foundation

/// The seven notes and `state.json` in one folder. Writes are debounced and atomic; a failed
/// write keeps the edit in memory and retries.
public final class NoteStore {
    public static let tabCount = 7
    static let retryInterval: TimeInterval = 5

    public let folder: URL
    public private(set) var state: JotState
    public var onSaveResult: ((Error?) -> Void)?
    /// A note changed outside jot while it held an unsaved edit: that outside version was copied
    /// here before jot's edit replaced it.
    public var onConflictCopy: ((URL) -> Void)?
    /// state.json was there but would not decode: it was moved here and the defaults used, so
    /// the next save does not overwrite it.
    public private(set) var unreadableState: URL?

    private var texts: [String]
    private var diskStamps: [Date?]
    private var dirtyTabs = Set<Int>()
    private var stateDirty = false
    private let debounce: TimeInterval
    private var pending: DispatchWorkItem?

    public init(folder: URL, debounce: TimeInterval = 0.4) {
        self.folder = folder
        self.debounce = debounce
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let urls = (0..<Self.tabCount).map { Self.noteURL(in: folder, $0) }
        texts = urls.map(Self.readNote)
        diskStamps = urls.map(Self.modificationDate)
        let stateURL = Self.stateURL(in: folder)
        if let data = try? Data(contentsOf: stateURL) {
            if let decoded = try? JSONDecoder().decode(JotState.self, from: data) {
                state = decoded
            } else {
                state = JotState()
                let aside = Self.asideURL(in: folder, "state.unreadable", ext: "json")
                if (try? FileManager.default.moveItem(at: stateURL, to: aside)) != nil { unreadableState = aside }
            }
        } else {
            state = JotState()
        }
    }

    static func noteURL(in folder: URL, _ tab: Int) -> URL { folder.appendingPathComponent("\(tab + 1).txt") }
    static func stateURL(in folder: URL) -> URL { folder.appendingPathComponent("state.json") }
    /// A missing note is empty. A note saved elsewhere in another encoding is decoded (sniffed,
    /// else Latin-1, which accepts any bytes) rather than shown blank, since the next save
    /// overwrites the file with whatever the editor holds.
    static func readNote(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        var encoding = String.Encoding.utf8
        if let sniffed = try? String(contentsOf: url, usedEncoding: &encoding) { return sniffed }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    public func noteURL(_ tab: Int) -> URL { Self.noteURL(in: folder, tab) }

    /// A free `<name>-<yyyyMMdd-HHmmss>.<ext>` in `folder`, for a file kept aside rather than lost.
    static func asideURL(in folder: URL, _ name: String, ext: String) -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = f.string(from: Date())
        var url = folder.appendingPathComponent("\(name)-\(stamp).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(name)-\(stamp)-\(n).\(ext)")
            n += 1
        }
        return url
    }

    /// Where an outside version of note `tab` is kept: `N.conflict-<yyyyMMdd-HHmmss>.txt`, beside it.
    private func conflictURL(_ tab: Int) -> URL { Self.asideURL(in: folder, "\(tab + 1).conflict", ext: "txt") }
    public func text(_ tab: Int) -> String { texts[tab] }

    public func setText(_ text: String, tab: Int) {
        guard texts[tab] != text else { return }
        texts[tab] = text
        dirtyTabs.insert(tab)
        schedule(after: debounce)
    }

    public func updateState(_ change: (inout JotState) -> Void) {
        var next = state
        change(&next)
        next = next.normalized()
        guard next != state else { return }
        state = next
        stateDirty = true
        schedule(after: debounce)
    }

    /// Picks up an edit made outside jot. Never discards an unsaved jot edit.
    @discardableResult
    public func reloadIfChangedOnDisk(_ tab: Int) -> Bool {
        guard !dirtyTabs.contains(tab) else { return false }
        let url = noteURL(tab)
        let stamp = Self.modificationDate(url)
        guard stamp != diskStamps[tab] else { return false }
        texts[tab] = Self.readNote(url)
        diskStamps[tab] = stamp
        return true
    }

    public func flush() throws {
        pending?.cancel()
        pending = nil
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for tab in dirtyTabs.sorted() {
            let url = noteURL(tab)
            // Changed outside jot since jot last read or wrote it: keep that version beside the
            // note before jot's edit replaces it, so neither side's text is lost. Once copied, that
            // version counts as seen, so a write that fails and is retried is not copied again.
            if let onDisk = Self.modificationDate(url), onDisk != diskStamps[tab] {
                let copy = conflictURL(tab)
                try FileManager.default.copyItem(at: url, to: copy)
                diskStamps[tab] = onDisk
                onConflictCopy?(copy)
            }
            try Data(texts[tab].utf8).write(to: url, options: .atomic)
            diskStamps[tab] = Self.modificationDate(url)
            dirtyTabs.remove(tab)
        }
        if stateDirty {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: Self.stateURL(in: folder), options: .atomic)
            stateDirty = false
        }
    }

    public func flushReportingResult() {
        do {
            try flush()
            onSaveResult?(nil)
        } catch {
            onSaveResult?(error)
            schedule(after: Self.retryInterval)
        }
    }

    private func schedule(after delay: TimeInterval) {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.flushReportingResult() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
