import SwiftData
import SwiftUI

@main
struct SerienVollstaendigkeitsprueferApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: FolderBinding.self, APICacheEntry.self, ScanHistoryEntry.self)
        } catch {
            fatalError("Die lokale Datenbank konnte nicht geöffnet werden: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup("Serien-Vollständigkeitsprüfer") {
            ContentView(modelContext: modelContainer.mainContext)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1_120, height: 760)
        .windowToolbarStyle(.unifiedCompact)
    }
}
