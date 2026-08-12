import Foundation

struct LocalEpisodeFile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let fileURL: URL
    let fileName: String
    let fileSize: Int64?

    init(id: UUID = UUID(), fileURL: URL, fileSize: Int64? = nil) {
        self.id = id
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.fileSize = fileSize
    }
}

struct FileScanOutput: Sendable {
    let videoFiles: [LocalEpisodeFile]
    let inaccessiblePaths: [String]
}

enum ManualReviewReason: String, Codable, CaseIterable, Sendable {
    case noEpisodePattern
    case multipartEpisode
    case excludedExtra
    case seasonPack
    case unreadableFile

    var localizedDescription: String {
        switch self {
        case .noEpisodePattern: localized("Keine Staffel- und Folgennummer erkannt", "No season and episode number detected")
        case .multipartEpisode: localized("Mehrteilige Datei muss manuell geprüft werden", "Multipart file needs manual review")
        case .excludedExtra: localized("Zusatzdatei, Sample oder Trailer", "Extra, sample, or trailer")
        case .seasonPack: localized("Staffelpaket ohne einzelne Episodennummer", "Season package without an individual episode number")
        case .unreadableFile: localized("Datei konnte nicht gelesen werden", "File could not be read")
        }
    }
}

struct ParsedEpisode: Codable, Hashable, Sendable {
    let season: Int
    let episode: Int
    let inferredTitle: String?
}

enum EpisodeParseResult: Equatable, Sendable {
    case episode(ParsedEpisode)
    case manualReview(ManualReviewReason)
}

struct TVMazeShow: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let premiered: String?
    let language: String?
}

struct OnlineEpisode: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let season: Int
    let number: Int?
    let name: String
    let airdate: String?
    let type: String?

    var isSpecial: Bool { season == 0 || type?.lowercased() == "significant_special" }

    func hasAired(by referenceDate: Date) -> Bool {
        guard let airdate else { return true }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: airdate) else { return true }
        return date <= referenceDate
    }
}

enum EpisodeStatus: String, Codable, CaseIterable, Sendable {
    case present
    case presentWithTitleDifference
    case missing
    case duplicate
    case manualReview
    case unreleased
    case special

    var localizedDescription: String {
        switch self {
        case .present: localized("Vorhanden", "Present")
        case .presentWithTitleDifference: localized("Vorhanden, Titel abweichend", "Present, title differs")
        case .missing: localized("Fehlt", "Missing")
        case .duplicate: localized("Doppelt", "Duplicate")
        case .manualReview: localized("Manuell prüfen", "Manual review")
        case .unreleased: localized("Noch nicht veröffentlicht", "Not yet released")
        case .special: localized("Special", "Special")
        }
    }
}

struct EpisodeComparison: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let season: Int?
    let episode: Int?
    let expectedTitle: String?
    let files: [LocalEpisodeFile]
    let status: EpisodeStatus
    let note: String?

    init(season: Int?, episode: Int?, expectedTitle: String?, files: [LocalEpisodeFile], status: EpisodeStatus, note: String? = nil) {
        self.id = "\(season.map(String.init) ?? "x")-\(episode.map(String.init) ?? "x")-\(status.rawValue)-\(files.map(\.id.uuidString).joined(separator: ","))"
        self.season = season
        self.episode = episode
        self.expectedTitle = expectedTitle
        self.files = files
        self.status = status
        self.note = note
    }
}

struct SeasonResult: Identifiable, Codable, Hashable, Sendable {
    let season: Int
    let comparisons: [EpisodeComparison]

    var id: Int { season }
}

struct ScanSummary: Codable, Hashable, Sendable {
    let completeSeasons: Int
    let missing: Int
    let duplicates: Int
    let manualReview: Int
    let unreleased: Int
}

struct ScanResult: Codable, Hashable, Sendable {
    let series: TVMazeShow
    let scannedAt: Date
    let seasons: [SeasonResult]
    let summary: ScanSummary
}

enum ScanState: Equatable {
    case idle
    case scanning
    case awaitingSeriesSelection
    case completed
    case noVideos
    case cancelled
    case failed

    var message: String {
        switch self {
        case .idle: localized("Wählen Sie einen Serienordner aus, um die Prüfung zu starten.", "Choose a series folder to start the check.")
        case .scanning: localized("Prüfung läuft …", "Checking …")
        case .awaitingSeriesSelection: localized("Bitte bestätigen Sie die passende Serie.", "Please confirm the matching series.")
        case .completed: localized("Prüfung abgeschlossen", "Check complete")
        case .noVideos: localized("Keine unterstützten Videodateien gefunden", "No supported video files found")
        case .cancelled: localized("Prüfung abgebrochen", "Check cancelled")
        case .failed: localized("Prüfung nicht abgeschlossen", "Check not completed")
        }
    }
}

struct EpisodeTableRow: Identifiable, Hashable {
    let comparison: EpisodeComparison

    var id: String { comparison.id }
    var seasonLabel: String {
        guard let season = comparison.season, season >= 0 else { return "—" }
        return season == 0 ? localized("Special", "Special") : String(format: "S%02d", season)
    }
    var episodeLabel: String {
        guard let episode = comparison.episode else { return "—" }
        return String(format: "E%02d", episode)
    }
    var localFileNames: String { comparison.files.map(\.fileName).joined(separator: "\n") }
}

struct ScanHistoryRow: Identifiable, Hashable {
    let id: String
    let folderPath: String
    let seriesName: String?
    let scannedAt: Date
    let summaryText: String
    let result: ScanResult?
}

enum ResultFilter: String, CaseIterable, Identifiable {
    case all
    case missing
    case duplicate
    case manualReview
    case complete

    var id: String { rawValue }
    var localizedDescription: String {
        switch self {
        case .all: localized("Alle", "All")
        case .missing: localized("Fehlend", "Missing")
        case .duplicate: localized("Doppelt", "Duplicates")
        case .manualReview: localized("Manuell prüfen", "Manual review")
        case .complete: localized("Vollständig", "Complete")
        }
    }
}
