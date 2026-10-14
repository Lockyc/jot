public enum Fuzzy {
    /// Case-insensitive subsequence match; nil when `query` is not a subsequence of `candidate`.
    /// Consecutive matched characters and matches at word starts score higher.
    public static func score(_ query: String, _ candidate: String) -> Int? {
        let q = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !q.isEmpty else { return 0 }
        let c = Array(candidate.lowercased())
        var qi = 0, score = 0, previous = -2
        for (i, ch) in c.enumerated() where qi < q.count && ch == q[qi] {
            score += 1
            if previous == i - 1 { score += 3 }
            if i == 0 || !c[i - 1].isLetter { score += 2 }
            previous = i
            qi += 1
        }
        return qi == q.count ? score : nil
    }

    public static func rank<T>(_ items: [T], query: String, key: (T) -> String) -> [T] {
        items.enumerated()
            .compactMap { offset, item in score(query, key(item)).map { (offset, item, $0) } }
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
            .map(\.1)
    }
}
