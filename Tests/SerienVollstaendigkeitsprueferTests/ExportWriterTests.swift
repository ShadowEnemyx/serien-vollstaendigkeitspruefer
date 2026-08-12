import XCTest
@testable import SerienVollstaendigkeitspruefer

@MainActor
final class ExportWriterTests: XCTestCase {
    func testCSVUsesSemicolonsAndEscapesQuotes() {
        let file = LocalEpisodeFile(fileURL: URL(fileURLWithPath: "/tmp/Meine;\"Serie\" S01E01.mkv"))
        let comparison = EpisodeComparison(season: 1, episode: 1, expectedTitle: "Ein; \"Titel\"", files: [file], status: .present)
        let result = ScanResult(series: TVMazeShow(id: 1, name: "Serie", premiered: nil, language: nil), scannedAt: .now, seasons: [SeasonResult(season: 1, comparisons: [comparison])], summary: ScanSummary(completeSeasons: 1, missing: 0, duplicates: 0, manualReview: 0, unreleased: 0))

        let csv = ExportWriter.csvReport(result)
        XCTAssertTrue(csv.contains(";"))
        XCTAssertTrue(csv.contains("\"\"Titel\"\""))
    }
}
