import AppKit
import Combine
import Foundation
import SwiftData

@MainActor
final class ScanViewModel: ObservableObject {
    @Published private(set) var selectedFolderURL: URL?
    @Published private(set) var result: ScanResult?
    @Published private(set) var candidates: [TVMazeShow] = []
    @Published private(set) var state: ScanState = .idle
    @Published private(set) var progressText = ScanState.idle.message
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var filter: ResultFilter = .all
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var history: [ScanHistoryRow] = []
    @Published var selectedHistoryID: String?
    @Published private(set) var folderNeedsReselection = false

    var isScanning: Bool { state == .scanning }
    var canScanSelectedFolder: Bool { selectedFolderURL != nil && !folderNeedsReselection }
    var availableSeasons: [Int] {
        result?.seasons.map(\.season).filter { $0 >= 0 } ?? []
    }

    private let modelContext: ModelContext
    private let scanner: FileScanner
    private let matcher: SeriesMatcher
    private let comparator: EpisodeComparator
    private let folderAccessManager: FolderAccessManager
    private let seriesData: any SeriesDataProviding
    private var pendingScan: PendingScan?
    private var scanTask: Task<Void, Never>?

    init(
        modelContext: ModelContext,
        scanner: FileScanner = FileScanner(),
        matcher: SeriesMatcher = SeriesMatcher(),
        comparator: EpisodeComparator = EpisodeComparator(),
        folderAccessManager: FolderAccessManager = FolderAccessManager(),
        seriesData: (any SeriesDataProviding)? = nil
    ) {
        self.modelContext = modelContext
        self.scanner = scanner
        self.matcher = matcher
        self.comparator = comparator
        self.folderAccessManager = folderAccessManager
        self.seriesData = seriesData ?? TVMazeClient(modelContext: modelContext)
        reloadHistory()
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = localized("Wählen Sie den Serienordner aus, der ausschließlich gelesen werden soll.", "Choose the series folder to be read-only analyzed.")
        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        scanTask?.cancel()
        selectedFolderURL = folderURL
        folderNeedsReselection = false
        selectedHistoryID = nil
        result = nil
        candidates = []
        pendingScan = nil
        lastScanDate = nil
        noticeMessage = nil
        errorMessage = nil
        state = .idle
        progressText = folderURL.path
    }

    func scan(forceRefresh: Bool = false) {
        guard let folderURL = selectedFolderURL else {
            showError(localized("Bitte wählen Sie zuerst einen Serienordner aus.", "Please choose a series folder first."))
            return
        }
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            await self?.performScan(folderURL: folderURL, forceRefresh: forceRefresh)
        }
    }

    func selectSeries(_ show: TVMazeShow) {
        guard let pendingScan else {
            showError(localized("Die Auswahl ist nicht mehr gültig. Starten Sie die Prüfung bitte erneut.", "This selection is no longer valid. Please start the check again."))
            return
        }
        candidates = []
        do {
            try storeBinding(for: pendingScan.folderURL, show: show)
        } catch {
            appendNotice("\(localized("Die Serienzuordnung konnte nicht gespeichert werden.", "The series assignment could not be saved.")) \(error.localizedDescription)")
        }
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            await self?.performComparison(files: pendingScan.files, show: show, forceRefresh: pendingScan.forceRefresh, folderURL: pendingScan.folderURL)
        }
    }

    func dismissSeriesSelection() {
        candidates = []
        pendingScan = nil
        state = .idle
        progressText = localized("Serienauswahl abgebrochen", "Series selection cancelled")
    }

    func cancelScan() {
        guard isScanning else { return }
        progressText = localized("Prüfung wird abgebrochen …", "Cancelling check …")
        scanTask?.cancel()
    }

    /// Entfernt ausschließlich die gespeicherte TVmaze-Zuordnung dieses Ordners
    /// und startet danach die reguläre, dateinamengestützte Serienauswahl.
    func chooseDifferentSeries() {
        guard let folderURL = selectedFolderURL else {
            showError(localized("Bitte wählen Sie zuerst einen Serienordner aus.", "Please choose a series folder first."))
            return
        }
        do {
            if let existing = binding(forPath: folderURL.path) {
                modelContext.delete(existing)
                try modelContext.save()
            }
            result = nil
            candidates = []
            pendingScan = nil
            appendNotice(localized("Die gespeicherte Serienzuordnung wurde entfernt. Bitte wählen Sie die passende Serie aus.", "The saved series assignment was removed. Please choose the matching series."))
            scan()
        } catch {
            showError("\(localized("Die gespeicherte Serienzuordnung konnte nicht entfernt werden.", "The saved series assignment could not be removed.")) \(error.localizedDescription)")
        }
    }

    func restoreHistory(_ row: ScanHistoryRow) {
        selectedHistoryID = row.id
        result = row.result
        lastScanDate = row.scannedAt
        candidates = []
        pendingScan = nil
        state = row.result == nil ? .failed : .completed
        progressText = row.summaryText

        guard let binding = binding(forPath: row.folderPath) else {
            selectedFolderURL = URL(fileURLWithPath: row.folderPath, isDirectory: true)
            folderNeedsReselection = true
            appendNotice(localized("Für diesen Verlaufseintrag muss der Ordner vor einer neuen Prüfung erneut ausgewählt werden.", "For this history entry, choose the folder again before running a new check."))
            return
        }
        do {
            let resolved = try folderAccessManager.resolve(bookmarkData: binding.bookmarkData)
            selectedFolderURL = resolved.url
            folderNeedsReselection = false
            if let refreshedBookmark = resolved.refreshedBookmark {
                binding.bookmarkData = refreshedBookmark
                binding.updatedAt = .now
                try modelContext.save()
            }
        } catch {
            selectedFolderURL = URL(fileURLWithPath: row.folderPath, isDirectory: true)
            folderNeedsReselection = true
            appendNotice(error.localizedDescription)
        }
    }

    func rows(for season: Int? = nil) -> [EpisodeTableRow] {
        let comparisons = result?.seasons
            .filter { season == nil || $0.season == season }
            .flatMap(\.comparisons) ?? []
        return comparisons
            .filter(matchesFilter)
            .map(EpisodeTableRow.init(comparison:))
            .sorted {
                (($0.comparison.season ?? Int.max), ($0.comparison.episode ?? Int.max), $0.id) <
                (($1.comparison.season ?? Int.max), ($1.comparison.episode ?? Int.max), $1.id)
            }
    }

    func exportText() {
        guard let result else { return }
        do {
            try ExportWriter.exportText(result)
        } catch {
            showError("\(localized("Der Textbericht konnte nicht exportiert werden.", "The text report could not be exported.")) \(error.localizedDescription)")
        }
    }

    func exportCSV() {
        guard let result else { return }
        do {
            try ExportWriter.exportCSV(result)
        } catch {
            showError("\(localized("Die CSV-Datei konnte nicht exportiert werden.", "The CSV file could not be exported.")) \(error.localizedDescription)")
        }
    }

    private func performScan(folderURL: URL, forceRefresh: Bool) async {
        state = .scanning
        progressText = localized("Videodateien werden gesucht …", "Searching for video files …")
        errorMessage = nil
        noticeMessage = nil
        candidates = []
        pendingScan = nil
        let accessGranted = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { folderURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let output = try await scanner.scan(folderURL: folderURL)
            try Task.checkCancellation()
            if !output.inaccessiblePaths.isEmpty {
                appendNotice("\(output.inaccessiblePaths.count) \(localized("Pfade konnten nicht gelesen werden.", "paths could not be read."))")
            }
            guard !output.videoFiles.isEmpty else {
                result = nil
                state = .noVideos
                progressText = state.message
                return
            }

            if let binding = binding(forPath: folderURL.path) {
                let show = TVMazeShow(id: binding.showID, name: binding.showName, premiered: nil, language: nil)
                await performComparison(files: output.videoFiles, show: show, forceRefresh: forceRefresh, folderURL: folderURL)
            } else {
                progressText = localized("Serie wird bei TVmaze gesucht …", "Searching TVmaze for the series …")
                let queries = matcher.searchQueries(for: folderURL, files: output.videoFiles)
                var showsByID: [Int: TVMazeShow] = [:]
                for query in queries {
                    try Task.checkCancellation()
                    let searchResults = try await seriesData.searchShows(query: query)
                    for show in searchResults { showsByID[show.id] = show }
                }
                try Task.checkCancellation()
                let matches = matcher.rankCandidates(Array(showsByID.values), for: folderURL, files: output.videoFiles)
                pendingScan = PendingScan(folderURL: folderURL, files: output.videoFiles, forceRefresh: forceRefresh)
                candidates = matches
                if matches.isEmpty {
                    state = .failed
                    showError(localized("Bei TVmaze wurde weder zum Ordnernamen noch zu den erkannten Dateinamen eine passende Serie gefunden.", "TVmaze found no matching series for the folder name or detected filenames."))
                } else {
                    state = .awaitingSeriesSelection
                    progressText = state.message
                    if let primaryQuery = queries.first {
                        appendNotice("\(localized("Die Serienauswahl wird anhand der Videodateien und des Stammordners bewertet. Erkannter Dateiname:", "The series choices are ranked using video filenames and the root folder. Detected filename:")) „\(primaryQuery)“.")
                    }
                }
            }
        } catch is CancellationError {
            state = .cancelled
            progressText = state.message
        } catch {
            state = .failed
            progressText = state.message
            showError(error.localizedDescription)
        }
    }

    private func performComparison(files: [LocalEpisodeFile], show: TVMazeShow, forceRefresh: Bool, folderURL: URL) async {
        state = .scanning
        progressText = localized("Episodenliste wird geladen …", "Loading episode list …")
        do {
            let episodes = try await seriesData.loadEpisodes(showID: show.id, forceRefresh: forceRefresh)
            try Task.checkCancellation()
            let scanResult = comparator.compare(localFiles: files, onlineEpisodes: episodes, series: show)
            result = scanResult
            lastScanDate = scanResult.scannedAt
            state = .completed
            progressText = state.message
            if seriesData.lastResponseUsedStaleCache {
                appendNotice(localized("TVmaze war nicht erreichbar; es werden zwischengespeicherte Daten angezeigt.", "TVmaze was unavailable; cached data is shown."))
            }
            if let warning = seriesData.lastWarning { appendNotice(warning) }
            do {
                modelContext.insert(ScanHistoryEntry(folderPath: folderURL.path, result: scanResult))
                try modelContext.save()
                reloadHistory()
            } catch {
                appendNotice("\(localized("Der Scanverlauf konnte nicht gespeichert werden.", "The check history could not be saved.")) \(error.localizedDescription)")
            }
        } catch is CancellationError {
            state = .cancelled
            progressText = state.message
        } catch {
            state = .failed
            progressText = localized("Lokaler Scan abgeschlossen, Online-Vergleich nicht verfügbar", "Local scan complete, online comparison unavailable")
            showError(error.localizedDescription)
            do {
                modelContext.insert(ScanHistoryEntry(folderPath: folderURL.path, result: nil))
                try modelContext.save()
                reloadHistory()
            } catch {
                appendNotice("\(localized("Der Scanverlauf konnte nicht gespeichert werden.", "The check history could not be saved.")) \(error.localizedDescription)")
            }
        }
    }

    private func matchesFilter(_ comparison: EpisodeComparison) -> Bool {
        switch filter {
        case .all: true
        case .missing: comparison.status == .missing
        case .duplicate: comparison.status == .duplicate
        case .manualReview: comparison.status == .manualReview
        case .complete: [.present, .presentWithTitleDifference].contains(comparison.status)
        }
    }

    private func binding(forPath folderPath: String) -> FolderBinding? {
        let descriptor = FetchDescriptor<FolderBinding>(predicate: #Predicate { $0.folderPath == folderPath })
        return try? modelContext.fetch(descriptor).first
    }

    private func storeBinding(for folderURL: URL, show: TVMazeShow) throws {
        let bookmark = try folderAccessManager.bookmark(for: folderURL)
        if let existing = binding(forPath: folderURL.path) {
            existing.bookmarkData = bookmark
            existing.showID = show.id
            existing.showName = show.name
            existing.updatedAt = .now
        } else {
            modelContext.insert(FolderBinding(folderURL: folderURL, bookmarkData: bookmark, show: show))
        }
        try modelContext.save()
    }

    private func reloadHistory() {
        let descriptor = FetchDescriptor<ScanHistoryEntry>(sortBy: [SortDescriptor(\.scannedAt, order: .reverse)])
        do {
            history = try modelContext.fetch(descriptor).map { entry in
                let result = entry.resultPayload.flatMap { try? JSONDecoder().decode(ScanResult.self, from: $0) }
                return ScanHistoryRow(
                    id: "\(entry.folderPath)#\(entry.scannedAt.timeIntervalSinceReferenceDate)",
                    folderPath: entry.folderPath,
                    seriesName: result?.series.name,
                    scannedAt: entry.scannedAt,
                    summaryText: entry.summaryText,
                    result: result
                )
            }
        } catch {
            appendNotice("\(localized("Der Scanverlauf konnte nicht geladen werden.", "The check history could not be loaded.")) \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
    }

    private func appendNotice(_ message: String) {
        guard !message.isEmpty else { return }
        if let noticeMessage, !noticeMessage.contains(message) {
            self.noticeMessage = "\(noticeMessage)\n\(message)"
        } else if noticeMessage == nil {
            noticeMessage = message
        }
    }
}

private struct PendingScan {
    let folderURL: URL
    let files: [LocalEpisodeFile]
    let forceRefresh: Bool
}
