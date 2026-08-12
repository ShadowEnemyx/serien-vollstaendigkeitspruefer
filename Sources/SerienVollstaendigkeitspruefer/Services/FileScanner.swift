import Foundation

struct FileScanner: Sendable {
    /// Bewusste Positivliste: Nur diese regulären Videodateien erscheinen im Scanergebnis.
    /// Untertitel, Bilder, NFO-Dateien, Archive und alle anderen Begleitdateien bleiben außen vor.
    private static let videoExtensions: Set<String> = [
        "mkv", "mp4", "m4v", "avi", "mov", "wmv", "webm", "flv", "ogv",
        "ts", "m2ts", "mts", "mpg", "mpeg", "vob", "3gp", "3g2"
    ]

    func scan(folderURL: URL) async throws -> FileScanOutput {
        let cancellation = ScanCancellationToken()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try Self.scanSynchronously(folderURL: folderURL, cancellation: cancellation)
            }.value
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func scanSynchronously(folderURL: URL, cancellation: ScanCancellationToken) throws -> FileScanOutput {
        var videoFiles: [LocalEpisodeFile] = []
        var inaccessiblePaths: [String] = []
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, _ in
                inaccessiblePaths.append(url.path)
                return true
            }
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        for case let url as URL in enumerator {
            if cancellation.isCancelled { throw CancellationError() }
            do {
                let values = try url.resourceValues(forKeys: keys)
                // Staffelordner (z. B. S01 und S02) werden bewusst vollständig
                // durchlaufen. Verknüpfte Ordner und Pakete bleiben dagegen außen
                // vor, damit der Scan nicht aus dem gewählten Serienordner hinausführt.
                if values.isDirectory == true {
                    if values.isSymbolicLink == true || values.isPackage == true {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                // AppleDouble-Dateien (._Dateiname) können auf externen Datenträgern
                // wie eigenständige .mkv-Dateien aussehen, enthalten aber nur Metadaten.
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      !url.lastPathComponent.hasPrefix("._"),
                      Self.videoExtensions.contains(url.pathExtension.lowercased()) else { continue }
                videoFiles.append(LocalEpisodeFile(fileURL: url, fileSize: values.fileSize.map(Int64.init)))
            } catch {
                inaccessiblePaths.append(url.path)
            }
        }
        return FileScanOutput(videoFiles: videoFiles, inaccessiblePaths: inaccessiblePaths)
    }
}

private final class ScanCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func cancel() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
