import Foundation
import SwiftData

@MainActor
protocol SeriesDataProviding: AnyObject {
    var lastWarning: String? { get }
    var lastResponseUsedStaleCache: Bool { get }

    func searchShows(query: String) async throws -> [TVMazeShow]
    func loadEpisodes(showID: Int, forceRefresh: Bool) async throws -> [OnlineEpisode]
}

enum TVMazeClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(Int)
    case noCachedData

    var errorDescription: String? {
        switch self {
        case .invalidURL: localized("Die TVmaze-Anfrage konnte nicht erstellt werden.", "The TVmaze request could not be created.")
        case .invalidResponse: localized("TVmaze hat eine unverständliche Antwort geliefert.", "TVmaze returned an invalid response.")
        case .requestFailed(let status): localized("TVmaze ist derzeit nicht erreichbar (HTTP \(status)).", "TVmaze is currently unavailable (HTTP \(status)).")
        case .noCachedData: localized("TVmaze ist nicht erreichbar und es liegen keine zwischengespeicherten Daten vor.", "TVmaze is unavailable and no cached data exists.")
        }
    }
}

@MainActor
final class TVMazeClient: SeriesDataProviding {
    private let modelContext: ModelContext
    private let session: URLSession
    private let cacheValidity: TimeInterval = 7 * 24 * 60 * 60
    private(set) var lastResponseUsedStaleCache = false
    private(set) var lastWarning: String?

    init(modelContext: ModelContext, session: URLSession = .shared) {
        self.modelContext = modelContext
        self.session = session
    }

    func searchShows(query: String) async throws -> [TVMazeShow] {
        let key = "search:\(query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
        var components = URLComponents(string: "https://api.tvmaze.com/search/shows")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { throw TVMazeClientError.invalidURL }
        let responses: [SearchResponse] = try await load(key: key, url: url, forceRefresh: false)
        return responses.map(\.show)
    }

    func loadEpisodes(showID: Int, forceRefresh: Bool) async throws -> [OnlineEpisode] {
        let key = "episodes:\(showID)"
        guard let url = URL(string: "https://api.tvmaze.com/shows/\(showID)/episodes?specials=1") else { throw TVMazeClientError.invalidURL }
        return try await load(key: key, url: url, forceRefresh: forceRefresh)
    }

    private func load<T: Codable>(key: String, url: URL, forceRefresh: Bool) async throws -> T {
        lastResponseUsedStaleCache = false
        lastWarning = nil
        let cached = cachedEntry(for: key)
        if !forceRefresh, let cached, Date.now.timeIntervalSince(cached.updatedAt) < cacheValidity,
           let decoded = try? JSONDecoder().decode(T.self, from: cached.payload) {
            return decoded
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Serien-Vollstaendigkeitspruefer/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw TVMazeClientError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw TVMazeClientError.requestFailed(http.statusCode) }
            let decoded = try JSONDecoder().decode(T.self, from: data)
            saveCache(key: key, payload: data)
            return decoded
        } catch {
            if let cached, let decoded = try? JSONDecoder().decode(T.self, from: cached.payload) {
                lastResponseUsedStaleCache = true
                return decoded
            }
            if error is TVMazeClientError { throw error }
            throw TVMazeClientError.noCachedData
        }
    }

    private func cachedEntry(for key: String) -> APICacheEntry? {
        let descriptor = FetchDescriptor<APICacheEntry>(predicate: #Predicate { $0.key == key })
        return try? modelContext.fetch(descriptor).first
    }

    private func saveCache(key: String, payload: Data) {
        if let existing = cachedEntry(for: key) {
            existing.payload = payload
            existing.updatedAt = .now
        } else {
            modelContext.insert(APICacheEntry(key: key, payload: payload))
        }
        do {
            try modelContext.save()
        } catch {
            lastWarning = "\(localized("Die TVmaze-Daten konnten nicht lokal zwischengespeichert werden.", "TVmaze data could not be cached locally.")) \(error.localizedDescription)"
        }
    }
}

private struct SearchResponse: Codable {
    let show: TVMazeShow
}
