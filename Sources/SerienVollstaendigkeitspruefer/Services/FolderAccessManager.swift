import Foundation

enum FolderAccessError: LocalizedError {
    case bookmarkUnavailable
    case bookmarkResolutionFailed

    var errorDescription: String? {
        switch self {
        case .bookmarkUnavailable:
            localized("Für diesen Ordner liegt keine gültige Zugriffsberechtigung vor. Wählen Sie ihn bitte erneut aus.", "This folder no longer has a valid access permission. Please choose it again.")
        case .bookmarkResolutionFailed:
            localized("Der gespeicherte Serienordner konnte nicht geöffnet werden. Prüfen Sie, ob das Laufwerk verbunden ist.", "The saved series folder could not be opened. Check whether the drive is connected.")
        }
    }
}

struct ResolvedFolder: Sendable {
    let url: URL
    let refreshedBookmark: Data?
}

struct FolderAccessManager: Sendable {
    func bookmark(for folderURL: URL) throws -> Data {
        try folderURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolve(bookmarkData: Data) throws -> ResolvedFolder {
        guard !bookmarkData.isEmpty else { throw FolderAccessError.bookmarkUnavailable }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let refreshedBookmark = isStale ? try bookmark(for: url) : nil
            return ResolvedFolder(url: url, refreshedBookmark: refreshedBookmark)
        } catch {
            throw FolderAccessError.bookmarkResolutionFailed
        }
    }
}
