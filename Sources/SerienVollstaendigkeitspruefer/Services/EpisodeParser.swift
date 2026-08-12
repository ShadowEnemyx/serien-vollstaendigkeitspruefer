import Foundation

struct EpisodeParser: Sendable {
    private let excludedTerms = ["sample", "trailer", "extra", "extras", "featurette", "behind the scenes", "interview"]

    func parse(fileName: String) -> EpisodeParseResult {
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let lowercased = stem.lowercased()

        if excludedTerms.contains(where: { lowercased.contains($0) }) {
            return .manualReview(.excludedExtra)
        }
        if firstMatch(in: stem, pattern: #"(?i)(?:s(?:eason)?\s*\d{1,2}|staffel\s*\d+)\s*[._ -]*complete\b"#) != nil {
            return .manualReview(.seasonPack)
        }
        if firstMatch(in: stem, pattern: #"(?i)s\d{1,2}\s*e\d{1,3}\s*(?:e|-|–)\s*(?:e\s*)?\d{1,3}"#) != nil ||
            firstMatch(in: stem, pattern: #"(?i)\d{1,2}\s*x\s*\d{1,3}\s*(?:e|x|-|–)\s*(?:e\s*)?\d{1,3}"#) != nil {
            return .manualReview(.multipartEpisode)
        }

        let patterns = [
            #"(?i)(?:^|[^a-z0-9])s(?:eason)?\s*0*(\d{1,2})\s*e(?:pisode)?\s*0*(\d{1,3})(?:$|[^0-9])"#,
            #"(?i)(?:^|[^0-9])(\d{1,2})\s*x\s*0*(\d{1,3})(?:$|[^0-9])"#,
            #"(?i)staffel\s*0*(\d{1,2})\s*folge\s*0*(\d{1,3})"#
        ]

        for pattern in patterns {
            guard let match = firstMatch(in: stem, pattern: pattern), match.count >= 3,
                  let season = Int(match[1]), let episode = Int(match[2]), season >= 0, episode > 0 else { continue }
            return .episode(ParsedEpisode(season: season, episode: episode, inferredTitle: inferredTitle(from: stem)))
        }
        return .manualReview(.noEpisodePattern)
    }

    /// Nutzt bei Bedarf den unmittelbaren Ordner als Staffelkontext. Damit werden
    /// Dateien in „S01“, „Staffel 1“, „Season 01“ oder „1“ korrekt Staffel 1
    /// zugeordnet, selbst wenn der Dateiname keine Staffelnummer enthält.
    func parse(fileURL: URL) -> EpisodeParseResult {
        let fileNameResult = parse(fileName: fileURL.lastPathComponent)
        guard let folderSeason = seasonNumber(fromFolderName: fileURL.deletingLastPathComponent().lastPathComponent) else {
            return fileNameResult
        }

        switch fileNameResult {
        case .episode(let parsed):
            // Eine vollständige SxxEyy-Nummer im Dateinamen ist eindeutiger als
            // die Ordnerstruktur und kann einen versehentlich falsch einsortierten
            // Eintrag zuverlässig auffangen. Der Ordner bleibt der Fallback.
            return .episode(parsed)
        case .manualReview(.noEpisodePattern):
            guard let episode = episodeNumberWithoutSeason(in: fileURL.lastPathComponent) else {
                return fileNameResult
            }
            return .episode(ParsedEpisode(season: folderSeason, episode: episode, inferredTitle: nil))
        case .manualReview:
            return fileNameResult
        }
    }

    private func firstMatch(in text: String, pattern: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let result = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<result.numberOfRanges).compactMap { index in
            let range = result.range(at: index)
            guard let swiftRange = Range(range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    private func inferredTitle(from stem: String) -> String? {
        let cleaned = stem
            .replacingOccurrences(of: #"(?i)s(?:eason)?\s*\d{1,2}\s*e(?:pisode)?\s*\d{1,3}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\d{1,2}\s*x\s*\d{1,3}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)staffel\s*\d{1,2}\s*folge\s*\d{1,3}"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ._-–"))
        return cleaned.isEmpty ? nil : cleaned
    }

    private func seasonNumber(fromFolderName folderName: String) -> Int? {
        let patterns = [
            #"(?i)^s\s*0*(\d{1,2})$"#,
            #"(?i)^staffel\s*0*(\d{1,2})$"#,
            #"(?i)^season\s*0*(\d{1,2})$"#,
            #"^0*(\d{1,2})$"#
        ]
        for pattern in patterns {
            guard let match = firstMatch(in: folderName, pattern: pattern), match.count >= 2,
                  let season = Int(match[1]), season >= 0 else { continue }
            return season
        }
        return nil
    }

    private func episodeNumberWithoutSeason(in fileName: String) -> Int? {
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let explicitEpisodePatterns = [
            #"(?i)(?:^|[^a-z0-9])e\s*0*(\d{1,3})(?:$|[^0-9])"#,
            #"(?i)(?:^|[^a-z0-9])episode\s*0*(\d{1,3})(?:$|[^0-9])"#,
            #"(?i)(?:^|[^a-z0-9])folge\s*0*(\d{1,3})(?:$|[^0-9])"#,
            #"(?:^|[._\s-])0*(\d{1,3})$"#
        ]
        for pattern in explicitEpisodePatterns {
            guard let match = firstMatch(in: stem, pattern: pattern), match.count >= 2,
                  let episode = Int(match[1]), episode > 0 else { continue }
            return episode
        }
        return nil
    }
}
