import Foundation
import SwiftData
import XCTest
@testable import SerienVollstaendigkeitspruefer

@MainActor
final class TVMazeClientTests: XCTestCase {
    func testUsesValidCachedSearchResponseWithoutNetworkRequest() async throws {
        let container = try inMemoryContainer()
        let payload = Data("""
        [{"score": 1.0, "show": {"id": 321, "name": "Rock & Roll", "premiered": "2020-01-01", "language": "English"}}]
        """.utf8)
        container.mainContext.insert(APICacheEntry(key: "search:rock & roll", payload: payload))
        try container.mainContext.save()

        let client = TVMazeClient(modelContext: container.mainContext, session: URLSession(configuration: .ephemeral))
        let shows = try await client.searchShows(query: "Rock & Roll")

        XCTAssertEqual(shows, [TVMazeShow(id: 321, name: "Rock & Roll", premiered: "2020-01-01", language: "English")])
        XCTAssertFalse(client.lastResponseUsedStaleCache)
    }

    private func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: FolderBinding.self,
            APICacheEntry.self,
            ScanHistoryEntry.self,
            configurations: configuration
        )
    }
}
