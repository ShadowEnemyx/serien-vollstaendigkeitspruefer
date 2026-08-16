import XCTest
@testable import SerienVollstaendigkeitspruefer

final class EpisodeParserTests: XCTestCase {
    private let parser = EpisodeParser()

    func testRecognizesAllRequiredEpisodePatterns() {
        assertEpisode("tvkids.danny.phantom.s01e15.mkv", season: 1, episode: 15)
        assertEpisode("Marvels Agents of S H I E L D S4E10.mp4", season: 4, episode: 10)
        assertEpisode("Zack und Cody - 2x05 - Titel.mkv", season: 2, episode: 5)
        assertEpisode("Serie Staffel 1 Folge 3.mkv", season: 1, episode: 3)
        assertEpisode("Show Season 01 Episode 03.m4v", season: 1, episode: 3)
        assertEpisode("Mädchen mit Löwen S01E04.mkv", season: 1, episode: 4)
        assertEpisode("Maedchen mit Loewen S01E05.mkv", season: 1, episode: 5)
    }

    func testRecognizesSeasonAndEpisodeThroughReleaseStyleSeparators() {
        assertEpisode("Marvels.Agents.of.S.H.I.E.L.D.[S.01].[E.02].[GERMAN].mkv", season: 1, episode: 2)
        assertEpisode("Die_Serie__S_02__E_011__[WEB-DL][1080p].mkv", season: 2, episode: 11)
        assertEpisode("Serie{Season-03}{Episode_004}[x265].mkv", season: 3, episode: 4)
        assertEpisode("Show - S-04-E--002 - [REPACK].mkv", season: 4, episode: 2)
        assertEpisode("Kryptische.Show.[05.x.007].mkv", season: 5, episode: 7)
    }

    func testTreatsMultipartAndExtrasAsManualReview() {
        XCTAssertEqual(parser.parse(fileName: "Show.S01E01E02.mkv"), .manualReview(.multipartEpisode))
        XCTAssertEqual(parser.parse(fileName: "Show.S01E01-E02.mkv"), .manualReview(.multipartEpisode))
        XCTAssertEqual(parser.parse(fileName: "Show.[S-01].[E-01]__E.02.mkv"), .manualReview(.multipartEpisode))
        XCTAssertEqual(parser.parse(fileName: "Show.S01E01.Sample.mkv"), .manualReview(.excludedExtra))
        XCTAssertEqual(parser.parse(fileName: "Show.S01E01.behind_the_scenes.mkv"), .manualReview(.excludedExtra))
        XCTAssertEqual(parser.parse(fileName: "Show.S04.COMPLETE.GERMAN.mkv"), .manualReview(.seasonPack))
    }

    func testRejectsIncompleteFileNames() {
        XCTAssertEqual(parser.parse(fileName: "Folge drei endgültig.mkv"), .manualReview(.noEpisodePattern))
        XCTAssertEqual(parser.parse(fileName: "Show Staffel 1.mkv"), .manualReview(.noEpisodePattern))
    }

    func testUsesImmediateSeasonFolderWhenFilenameHasNoSeasonNumber() {
        assertEpisodeInFolder("S01", fileName: "Marvels Agents of S H I E L D Folge 03.mkv", season: 1, episode: 3)
        assertEpisodeInFolder("Staffel 7", fileName: "Meine Serie Episode 12.mkv", season: 7, episode: 12)
        assertEpisodeInFolder("07", fileName: "Meine Serie - 04.mkv", season: 7, episode: 4)
        assertEpisodeInFolder("S.06", fileName: "Meine_Serie__[E_07]_[GERMAN].mkv", season: 6, episode: 7)
    }

    func testExplicitFilenameSeasonTakesPrecedenceOverFolderFallback() {
        assertEpisodeInFolder("S01", fileName: "Meine Serie S04E02.mkv", season: 4, episode: 2)
    }

    private func assertEpisode(_ filename: String, season: Int, episode: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(parser.parse(fileName: filename), .episode(ParsedEpisode(season: season, episode: episode, inferredTitle: parserTitle(filename))), file: file, line: line)
    }

    private func parserTitle(_ filename: String) -> String? {
        switch parser.parse(fileName: filename) {
        case .episode(let parsed): parsed.inferredTitle
        case .manualReview: nil
        }
    }

    private func assertEpisodeInFolder(_ folder: String, fileName: String, season: Int, episode: Int, file: StaticString = #filePath, line: UInt = #line) {
        let url = URL(fileURLWithPath: "/tmp/Serie/\(folder)/\(fileName)")
        guard case .episode(let parsed) = parser.parse(fileURL: url) else {
            return XCTFail("Keine Episode erkannt: \(url.path)", file: file, line: line)
        }
        XCTAssertEqual(parsed.season, season, file: file, line: line)
        XCTAssertEqual(parsed.episode, episode, file: file, line: line)
    }
}
