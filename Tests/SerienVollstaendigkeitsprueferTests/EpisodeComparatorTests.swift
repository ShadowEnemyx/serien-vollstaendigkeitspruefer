import XCTest
@testable import SerienVollstaendigkeitspruefer

final class EpisodeComparatorTests: XCTestCase {
    func testComparesMissingDuplicatesSpecialsAndUnreleasedEpisodes() {
        let files = [
            file("Meine Serie S01E01 Pilot.mkv"),
            file("Meine Serie S01E03 First.mkv"),
            file("Meine Serie S01E03 Alternative.mkv"),
            file("Meine Serie S02E01 Unbekannt.mkv")
        ]
        let episodes = [
            episode(id: 1, season: 1, number: 1, name: "Pilot", airdate: "2020-01-01"),
            episode(id: 2, season: 1, number: 2, name: "Second", airdate: "2020-01-08"),
            episode(id: 3, season: 1, number: 3, name: "Third", airdate: "2020-01-15"),
            episode(id: 4, season: 1, number: 4, name: "Future", airdate: "2099-01-01"),
            episode(id: 5, season: 0, number: 1, name: "Special", airdate: "2020-01-01")
        ]
        let result = EpisodeComparator().compare(localFiles: files, onlineEpisodes: episodes, referenceDate: date("2026-01-01"), series: show)

        XCTAssertEqual(result.summary.missing, 1)
        XCTAssertEqual(result.summary.duplicates, 1)
        XCTAssertEqual(result.summary.unreleased, 1)
        XCTAssertEqual(result.summary.manualReview, 1)
        XCTAssertEqual(result.seasons.first(where: { $0.season == 0 })?.comparisons.first?.status, .special)
    }

    func testTitleDifferenceDoesNotMarkEpisodeAsMissing() {
        let result = EpisodeComparator().compare(
            localFiles: [file("Serie S01E01 Deutscher Titel.mkv")],
            onlineEpisodes: [episode(id: 1, season: 1, number: 1, name: "English Title", airdate: "2020-01-01")],
            referenceDate: date("2026-01-01"),
            series: show
        )
        XCTAssertEqual(result.summary.missing, 0)
        XCTAssertEqual(result.seasons[0].comparisons[0].status, .presentWithTitleDifference)
    }

    func testReleaseMetadataWithoutEpisodeTitleIsNotReportedAsTitleDifference() {
        let result = EpisodeComparator().compare(
            localFiles: [file("Meine Serie S01E01 1080p WEB-DL HEVC.mkv")],
            onlineEpisodes: [episode(id: 1, season: 1, number: 1, name: "English Title", airdate: "2020-01-01")],
            referenceDate: date("2026-01-01"),
            series: show
        )
        XCTAssertEqual(result.seasons[0].comparisons[0].status, .present)
    }

    func testComparesEpisodeUsingSeasonFolderWhenFilenameOmitsSeason() {
        let folderURL = URL(fileURLWithPath: "/tmp/Meine Serie/S02", isDirectory: true)
        let localFile = LocalEpisodeFile(fileURL: folderURL.appendingPathComponent("Meine Serie Folge 01.mkv"))
        let result = EpisodeComparator().compare(
            localFiles: [localFile],
            onlineEpisodes: [episode(id: 1, season: 2, number: 1, name: "Start", airdate: "2020-01-01")],
            referenceDate: date("2026-01-01"),
            series: show
        )

        XCTAssertEqual(result.summary.missing, 0)
        XCTAssertEqual(result.seasons.first?.comparisons.first?.status, .present)
    }

    func testDoesNotTreatExplicitlyDifferentSeasonsAsDuplicates() {
        let folderURL = URL(fileURLWithPath: "/tmp/Meine Serie/S01", isDirectory: true)
        let files = [
            LocalEpisodeFile(fileURL: folderURL.appendingPathComponent("Meine Serie S01E01.mkv")),
            LocalEpisodeFile(fileURL: folderURL.appendingPathComponent("Meine Serie S04E01.mkv"))
        ]
        let result = EpisodeComparator().compare(
            localFiles: files,
            onlineEpisodes: [
                episode(id: 1, season: 1, number: 1, name: "Pilot", airdate: "2020-01-01"),
                episode(id: 2, season: 4, number: 1, name: "Neustart", airdate: "2020-01-01")
            ],
            referenceDate: date("2026-01-01"),
            series: show
        )

        XCTAssertEqual(result.summary.duplicates, 0)
        XCTAssertEqual(result.summary.missing, 0)
    }

    private var show: TVMazeShow { TVMazeShow(id: 10, name: "Meine Serie", premiered: nil, language: nil) }
    private func file(_ name: String) -> LocalEpisodeFile { LocalEpisodeFile(fileURL: URL(fileURLWithPath: "/tmp/\(name)")) }
    private func episode(id: Int, season: Int, number: Int, name: String, airdate: String) -> OnlineEpisode { OnlineEpisode(id: id, season: season, number: number, name: name, airdate: airdate, type: nil) }
    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}
