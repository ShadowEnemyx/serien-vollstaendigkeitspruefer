import Foundation
import SwiftData

@Model
final class FolderBinding {
    @Attribute(.unique) var folderPath: String
    var bookmarkData: Data
    var showID: Int
    var showName: String
    var updatedAt: Date

    init(folderURL: URL, bookmarkData: Data, show: TVMazeShow) {
        folderPath = folderURL.path
        self.bookmarkData = bookmarkData
        showID = show.id
        showName = show.name
        updatedAt = .now
    }
}

@Model
final class APICacheEntry {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date

    init(key: String, payload: Data, updatedAt: Date = .now) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model
final class ScanHistoryEntry {
    var folderPath: String
    var scannedAt: Date
    var summaryText: String
    var resultPayload: Data?

    init(folderPath: String, result: ScanResult?) {
        self.folderPath = folderPath
        scannedAt = .now
        if let result {
            summaryText = "\(result.series.name): \(result.summary.missing) \(localized("fehlend", "missing")), \(result.summary.duplicates) \(localized("doppelt", "duplicates"))"
            resultPayload = try? JSONEncoder().encode(result)
        } else {
            summaryText = localized("Lokaler Scan ohne Online-Vergleich", "Local scan without online comparison")
            resultPayload = nil
        }
    }
}
