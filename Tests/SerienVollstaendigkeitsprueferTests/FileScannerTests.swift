import XCTest
@testable import SerienVollstaendigkeitspruefer

final class FileScannerTests: XCTestCase {
    func testScansSupportedExtensionsRecursivelyWithoutLoadingContents() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("Staffel 1", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(FileManager.default.createFile(atPath: nested.appendingPathComponent("Serie S01E01.mkv").path, contents: Data()))
        XCTAssertTrue(FileManager.default.createFile(atPath: nested.appendingPathComponent("Notiz.txt").path, contents: Data()))

        let output = try await FileScanner().scan(folderURL: root)
        XCTAssertEqual(output.videoFiles.map(\.fileName), ["Serie S01E01.mkv"])
    }

    func testIncludesEpisodesFromMultipleSeasonSubfolders() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let seasonOne = root.appendingPathComponent("S01", isDirectory: true)
        let seasonTwo = root.appendingPathComponent("S02", isDirectory: true)
        try FileManager.default.createDirectory(at: seasonOne, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: seasonTwo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertTrue(FileManager.default.createFile(atPath: seasonOne.appendingPathComponent("Serie.S01E01.mkv").path, contents: Data()))
        XCTAssertTrue(FileManager.default.createFile(atPath: seasonTwo.appendingPathComponent("Serie.S02E03.mp4").path, contents: Data()))

        let output = try await FileScanner().scan(folderURL: root)

        XCTAssertEqual(Set(output.videoFiles.map(\.fileName)), ["Serie.S01E01.mkv", "Serie.S02E03.mp4"])
    }

    func testOnlyAddsKnownVideoFormatsAndIgnoresCompanionFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let accepted = ["Serie.S01E01.MKV", "Serie.S01E02.m2ts", "Serie.S01E03.wmv", "Serie.S01E04.mpeg"]
        let ignored = ["Serie.S01E01.srt", "Serie.nfo", "cover.jpg", "beschreibung.pdf", "Archiv.zip", "Ordner.DS_Store", "._Serie.S01E01.mkv"]
        for fileName in accepted + ignored {
            XCTAssertTrue(FileManager.default.createFile(atPath: root.appendingPathComponent(fileName).path, contents: Data()))
        }

        let output = try await FileScanner().scan(folderURL: root)

        XCTAssertEqual(Set(output.videoFiles.map(\.fileName)), Set(accepted))
    }

    func testReportsUnavailableRootFolderClearly() async {
        let unavailable = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-series-folder-\(UUID().uuidString)", isDirectory: true)

        do {
            _ = try await FileScanner().scan(folderURL: unavailable)
            XCTFail("An unavailable root folder must not be reported as an empty scan.")
        } catch let error as FileScannerError {
            XCTAssertEqual(error, .folderUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
