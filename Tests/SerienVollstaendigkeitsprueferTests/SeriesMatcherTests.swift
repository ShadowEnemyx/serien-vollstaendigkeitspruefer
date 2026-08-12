import XCTest
@testable import SerienVollstaendigkeitspruefer

final class SeriesMatcherTests: XCTestCase {
    func testUsesRecurringFilenameTitleWhenFolderHasTechnicalName() {
        let folderURL = URL(fileURLWithPath: "/Volumes/Extern/Filme/TEST_MARV", isDirectory: true)
        let files = [
            LocalEpisodeFile(fileURL: folderURL.appendingPathComponent("S01/Marvels Agents of S H I E L D S01E01.mkv")),
            LocalEpisodeFile(fileURL: folderURL.appendingPathComponent("S02/Marvels Agents of S H I E L D S02E03.mkv"))
        ]

        let queries = SeriesMatcher().searchQueries(for: folderURL, files: files)

        XCTAssertEqual(queries, ["Marvels Agents of S H I E L D", "Marvels Agents of", "TEST MARV"])
    }

    func testRanksFilenameMatchAheadOfIrrelevantTechnicalFolderMatch() {
        let folderURL = URL(fileURLWithPath: "/Volumes/Extern/Filme/TEST_MARV", isDirectory: true)
        let files = [
            LocalEpisodeFile(fileURL: folderURL.appendingPathComponent("S01/Marvels Agents of S H I E L D S01E01.mkv"))
        ]
        let candidates = [
            TVMazeShow(id: 1, name: "Mary Knows Best", premiered: nil, language: "English"),
            TVMazeShow(id: 31, name: "Marvel's Agents of S.H.I.E.L.D.", premiered: nil, language: "English")
        ]

        let ranked = SeriesMatcher().rankCandidates(candidates, for: folderURL, files: files)

        XCTAssertEqual(ranked.map(\.id), [31])
    }
}
