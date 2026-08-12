import Foundation

struct EpisodeComparator: Sendable {
    private let parser = EpisodeParser()

    func compare(localFiles: [LocalEpisodeFile], onlineEpisodes: [OnlineEpisode], referenceDate: Date = .now, series: TVMazeShow) -> ScanResult {
        var grouped: [EpisodeKey: [LocalEpisodeFile]] = [:]
        var manual: [EpisodeComparison] = []

        for file in localFiles {
            switch parser.parse(fileURL: file.fileURL) {
            case .episode(let parsed): grouped[EpisodeKey(season: parsed.season, episode: parsed.episode), default: []].append(file)
            case .manualReview(let reason):
                manual.append(EpisodeComparison(season: nil, episode: nil, expectedTitle: nil, files: [file], status: .manualReview, note: reason.localizedDescription))
            }
        }

        var bySeason: [Int: [EpisodeComparison]] = [:]
        for online in onlineEpisodes {
            if online.isSpecial {
                let files = online.number.flatMap { grouped.removeValue(forKey: EpisodeKey(season: 0, episode: $0)) } ?? []
                bySeason[0, default: []].append(EpisodeComparison(season: 0, episode: online.number, expectedTitle: online.name, files: files, status: .special))
                continue
            }
            guard let number = online.number else { continue }
            let key = EpisodeKey(season: online.season, episode: number)
            let files = grouped.removeValue(forKey: key) ?? []
            let status: EpisodeStatus
            if !online.hasAired(by: referenceDate) {
                status = .unreleased
            } else if files.isEmpty {
                status = .missing
            } else if files.count > 1 {
                status = .duplicate
            } else if hasTitleDifference(localName: files[0].fileName, expectedTitle: online.name, seriesName: series.name) {
                status = .presentWithTitleDifference
            } else {
                status = .present
            }
            bySeason[online.season, default: []].append(EpisodeComparison(season: online.season, episode: number, expectedTitle: online.name, files: files, status: status))
        }

        for (key, files) in grouped {
            bySeason[key.season, default: []].append(EpisodeComparison(season: key.season, episode: key.episode, expectedTitle: nil, files: files, status: .manualReview, note: localized("Nicht in der Episodenliste gefunden", "Not found in the episode list")))
        }
        if !manual.isEmpty { bySeason[-1, default: []].append(contentsOf: manual) }

        let seasons = bySeason.keys.sorted().map { season in
            SeasonResult(season: season, comparisons: bySeason[season, default: []].sorted { ($0.episode ?? Int.max) < ($1.episode ?? Int.max) })
        }
        let all = seasons.flatMap(\.comparisons)
        let completeSeasons = seasons.filter { result in
            result.season > 0 && !result.comparisons.contains { [.missing, .duplicate, .manualReview].contains($0.status) }
        }.count
        return ScanResult(
            series: series,
            scannedAt: .now,
            seasons: seasons,
            summary: ScanSummary(
                completeSeasons: completeSeasons,
                missing: all.filter { $0.status == .missing }.count,
                duplicates: all.filter { $0.status == .duplicate }.count,
                manualReview: all.filter { $0.status == .manualReview }.count,
                unreleased: all.filter { $0.status == .unreleased }.count
            )
        )
    }

    private func hasTitleDifference(localName: String, expectedTitle: String, seriesName: String) -> Bool {
        let normalizedExpected = normalize(expectedTitle)
        guard normalizedExpected.count >= 3 else { return false }
        guard case .episode(let parsed) = parser.parse(fileName: localName),
              let inferredTitle = parsed.inferredTitle else { return false }

        let technicalTerms = [
            "2160p", "1080p", "720p", "480p", "webrip", "webdl", "bluray", "bdrip",
            "x264", "x265", "h264", "h265", "hevc", "proper", "repack", "german", "english",
            "deutsch", "dubbed", "complete", "final", "aac", "ac3", "dts", "web", "dl"
        ]
        var candidate = normalize(inferredTitle)
        candidate = candidate.replacingOccurrences(of: normalize(seriesName), with: "")
        let remaining = technicalTerms.reduce(candidate) { partial, term in
            partial.replacingOccurrences(of: term, with: "")
        }
        guard remaining.count >= 4 else { return false }
        return !normalize(localName).contains(normalizedExpected)
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}

private struct EpisodeKey: Hashable, Sendable {
    let season: Int
    let episode: Int
}
