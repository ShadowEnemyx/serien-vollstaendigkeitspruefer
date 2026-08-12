import Foundation

struct SeriesMatcher: Sendable {
    func searchQuery(for folderURL: URL, files: [LocalEpisodeFile]) -> String {
        searchQueries(for: folderURL, files: files).first ?? folderURL.lastPathComponent
    }

    /// Gibt zuerst den Namen des ausgewählten Ordners zurück und versucht danach
    /// aus den wiederkehrenden Dateinamen sinnvollere Suchbegriffe abzuleiten.
    /// Dateinamen haben Vorrang, weil der Serien-Stammordner auch technisch
    /// benannt sein kann, etwa "TEST_MARV".
    func searchQueries(for folderURL: URL, files: [LocalEpisodeFile]) -> [String] {
        var queries: [String] = []

        let filenameTitles = files
            .map { normalizedSeriesName($0.fileName) }
            .filter { $0.split(separator: " ").count >= 2 }
        let titleCounts = Dictionary(grouping: filenameTitles, by: { canonicalKey(for: $0) })
        let rankedTitles = titleCounts.values
            .map { $0[0] }
            .sorted {
                let leftCount = titleCounts[canonicalKey(for: $0)]?.count ?? 0
                let rightCount = titleCounts[canonicalKey(for: $1)]?.count ?? 0
                return leftCount == rightCount ? $0.localizedCaseInsensitiveCompare($1) == .orderedAscending : leftCount > rightCount
            }

        for title in rankedTitles.prefix(5) {
            appendUnique(title, to: &queries)
            if let shortened = removingTrailingInitialism(from: title) {
                appendUnique(shortened, to: &queries)
            }
        }
        // Der Stammordner ist weiterhin ein wichtiges Fallback, falls die
        // Dateinamen keinen sauber verwertbaren Serientitel enthalten.
        appendUnique(normalizedSeriesName(folderURL.lastPathComponent), to: &queries)
        return queries
    }

    /// Sortiert TVmaze-Treffer nach der Übereinstimmung mit den lokalen
    /// Dateinamen. Irrelevante Fuzzy-Treffer eines technischen Ordnernamens
    /// werden verworfen, solange mindestens ein relevanter Treffer vorliegt.
    func rankCandidates(_ candidates: [TVMazeShow], for folderURL: URL, files: [LocalEpisodeFile]) -> [TVMazeShow] {
        let evidence = searchQueries(for: folderURL, files: files)
        let scored = candidates.map { show in
            (show: show, score: relevanceScore(title: show.name, evidence: evidence))
        }
        let relevant = scored.filter { $0.score > 0 }
        let source = relevant.isEmpty ? scored : relevant
        return source.sorted {
            $0.score == $1.score
                ? $0.show.name.localizedCaseInsensitiveCompare($1.show.name) == .orderedAscending
                : $0.score > $1.score
        }.map(\.show)
    }

    private func normalizedSeriesName(_ value: String) -> String {
        var name = URL(fileURLWithPath: value).deletingPathExtension().lastPathComponent
        name = name.replacingOccurrences(of: #"(?i)[._-]*(s(?:eason)?\s*\d{1,2}\s*e(?:pisode)?\s*\d{1,3}|\d{1,2}\s*x\s*\d{1,3}|staffel\s*\d+)\b.*$"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"[._-]+"#, with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removingTrailingInitialism(from value: String) -> String? {
        var words = value.split(separator: " ")
        while words.last?.count == 1 {
            words.removeLast()
        }
        guard words.count >= 2 else { return nil }
        return words.joined(separator: " ")
    }

    private func appendUnique(_ value: String, to queries: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, !queries.contains(where: { canonicalKey(for: $0) == canonicalKey(for: trimmed) }) else { return }
        queries.append(trimmed)
    }

    private func canonicalKey(for value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func relevanceScore(title: String, evidence: [String]) -> Int {
        let titleTokens = tokens(in: title)
        let titleCompact = compact(title)
        return evidence.reduce(into: 0) { score, query in
            let queryTokens = tokens(in: query)
            let overlap = titleTokens.intersection(queryTokens).count
            score += overlap * 100

            let queryCompact = compact(query)
            if !queryCompact.isEmpty, titleCompact == queryCompact {
                score += 1_000
            } else if queryCompact.count >= 6, titleCompact.contains(queryCompact) || queryCompact.contains(titleCompact) {
                score += 300
            }
        }
    }

    private func tokens(in value: String) -> Set<String> {
        Set(value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty })
    }

    private func compact(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
