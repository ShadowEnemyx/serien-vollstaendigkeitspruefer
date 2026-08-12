import XCTest
@testable import SerienVollstaendigkeitspruefer

final class FolderAccessManagerTests: XCTestCase {
    func testSecurityScopedBookmarkRoundTripPreservesFolderURL() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let manager = FolderAccessManager()
        let bookmark = try manager.bookmark(for: folder)
        let resolved = try manager.resolve(bookmarkData: bookmark)

        XCTAssertEqual(resolved.url.standardizedFileURL, folder.standardizedFileURL)
    }

    func testEmptyBookmarkShowsRecoverableError() {
        XCTAssertThrowsError(try FolderAccessManager().resolve(bookmarkData: Data())) { error in
            XCTAssertEqual(error.localizedDescription, "Für diesen Ordner liegt keine gültige Zugriffsberechtigung vor. Wählen Sie ihn bitte erneut aus.")
        }
    }
}
