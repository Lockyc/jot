import Foundation

/// The seven notes and `state.json` in one folder. Writes are debounced and atomic; a failed
/// write keeps the edit in memory and retries.
public final class NoteStore {
    public static let tabCount = 7
    static let retryInterval: TimeInterval = 5

    public let folder: URL
    public private(set) var state: JotState
    public var onSaveResult: ((Error?) -> Void)?

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
        texts = urls.map { (try? String(contentsOf: $0, encoding: .utf8)) ?? "" }
        diskStamps = urls.map(Self.modificationDate)
        if let data = try? Data(contentsOf: Self.stateURL(in: folder)),
           let decoded = try? JSONDecoder().decode(JotState.self, from: data) {
            state = decoded
        } else {
            state = JotState()
        }
    }

    static func noteURL(in folder: URL, _ tab: Int) -> URL { folder.appendingPathComponent("\(tab + 1).txt") }
    static func stateURL(in folder: URL) -> URL { folder.appendingPathComponent("state.json") }
    static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    public func noteURL(_ tab: Int) -> URL { Self.noteURL(in: folder, tab) }
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
        texts[tab] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        diskStamps[tab] = stamp
        return true
    }

    public func flush() throws {
        pending?.cancel()
        pending = nil
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for tab in dirtyTabs.sorted() {
            let url = noteURL(tab)
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
