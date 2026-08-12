import SwiftData
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ScanViewModel
    @State private var selectedSeason: Int?
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.german.rawValue

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: ScanViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 340)
        } detail: {
            detail
                .frame(minWidth: 760, minHeight: 560)
        }
        .toolbar { toolbar }
        .environment(\.locale, (AppLanguage(rawValue: appLanguage) ?? .german).locale)
        .sheet(isPresented: seriesSelectionPresented) {
            SeriesSelectionSheet(
                candidates: viewModel.candidates,
                onSelect: viewModel.selectSeries,
                onCancel: viewModel.dismissSeriesSelection
            )
        }
        .alert(localized("Prüfung fehlgeschlagen", "Check failed"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button(localized("TVmaze-Daten aktualisieren", "Refresh TVmaze data")) { viewModel.scan(forceRefresh: true) }
                    .disabled(!viewModel.canScanSelectedFolder || viewModel.isScanning)
                Button(localized("Andere Serie auswählen", "Choose a different series")) { viewModel.chooseDifferentSeries() }
                    .disabled(!viewModel.canScanSelectedFolder || viewModel.isScanning)
                Divider()
                Button(localized("Textbericht exportieren", "Export text report"), action: viewModel.exportText)
                    .disabled(viewModel.result == nil)
                Button(localized("CSV exportieren", "Export CSV"), action: viewModel.exportCSV)
                    .disabled(viewModel.result == nil)
            } label: {
                Label(localized("Mehr", "More"), systemImage: "ellipsis.circle")
            }

            Menu {
                Picker(localized("Sprache", "Language"), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
            } label: {
                Label(localized("Sprache", "Language"), systemImage: "globe")
            }

            if viewModel.isScanning {
                Button(role: .destructive, action: viewModel.cancelScan) {
                    Label(localized("Abbrechen", "Cancel"), systemImage: "xmark.circle")
                }
            }
        }
    }

    private var sidebar: some View {
        List {
            Section(localized("Aktueller Ordner", "Current folder")) {
                if let url = viewModel.selectedFolderURL {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(url.lastPathComponent).fontWeight(.semibold)
                            Text(url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                    }
                    if viewModel.folderNeedsReselection {
                        Label(localized("Ordnerzugriff erneuern", "Renew folder access"), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    ContentUnavailableView(localized("Kein Ordner", "No folder"), systemImage: "folder")
                        .font(.caption)
                }
            }

            Section(localized("Prüfverlauf", "Check history")) {
                if viewModel.history.isEmpty {
                    Text(localized("Noch keine gespeicherten Prüfungen.", "No saved checks yet."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.history) { row in
                        Button {
                            selectedSeason = nil
                            viewModel.restoreHistory(row)
                        } label: {
                            HistoryRow(row: row, isSelected: row.id == viewModel.selectedHistoryID)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(localized("Serienprüfung", "Series checker"))
    }

    private var detail: some View {
        ZStack {
            if let result = viewModel.result {
                resultView(result)
            } else {
                emptyState
            }

            if viewModel.isScanning {
                ProgressOverlay(message: viewModel.progressText)
            }
        }
        .safeAreaInset(edge: .bottom) {
            safetyNotice
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let symbol: String = switch viewModel.state {
        case .noVideos: "film"
        case .cancelled: "xmark.circle"
        case .failed: "exclamationmark.triangle"
        case .awaitingSeriesSelection: "rectangle.and.text.magnifyingglass"
        default: "film.stack"
        }
        VStack(spacing: 16) {
            ContentUnavailableView(
                viewModel.state == .idle ? localized("Serienordner prüfen", "Check series folder") : viewModel.state.message,
                systemImage: symbol,
                description: Text(viewModel.state == .idle && viewModel.selectedFolderURL == nil
                    ? viewModel.state.message
                    : viewModel.progressText)
            )
            startActions
            if let notice = viewModel.noticeMessage {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(10)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var startActions: some View {
        if viewModel.state != .awaitingSeriesSelection && !viewModel.isScanning {
            VStack(spacing: 10) {
                Button(action: viewModel.selectFolder) {
                    Label(viewModel.selectedFolderURL == nil ? localized("Serienordner auswählen", "Choose series folder") : localized("Anderen Serienordner auswählen", "Choose another series folder"), systemImage: "folder.badge.plus")
                }
                .controlSize(.large)

                Button(action: { viewModel.scan() }) {
                    Label(localized("Ordner prüfen", "Check folder"), systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canScanSelectedFolder)
            }
        }
    }

    private func resultView(_ result: ScanResult) -> some View {
        VStack(spacing: 0) {
            ResultHeader(
                result: result,
                folderURL: viewModel.selectedFolderURL,
                notice: viewModel.noticeMessage,
                filter: $viewModel.filter,
                selectedSeason: $selectedSeason,
                availableSeasons: viewModel.availableSeasons,
                onChooseFolder: viewModel.selectFolder,
                onChooseDifferentSeries: viewModel.chooseDifferentSeries
            )
            Divider()
            episodeTable
        }
        .navigationTitle(result.series.name)
    }

    private var episodeTable: some View {
        Table(viewModel.rows(for: selectedSeason)) {
            TableColumn(localized("Staffel", "Season")) { row in
                Text(row.seasonLabel).monospacedDigit()
            }
            .width(min: 70, ideal: 78, max: 92)

            TableColumn(localized("Folge", "Episode")) { row in
                Text(row.episodeLabel).monospacedDigit()
            }
            .width(min: 62, ideal: 72, max: 82)

            TableColumn(localized("Erwarteter Titel", "Expected title")) { row in
                Text(row.comparison.expectedTitle ?? "—")
                    .lineLimit(2)
            }
            .width(min: 170, ideal: 250)

            TableColumn(localized("Lokale Datei", "Local file")) { row in
                if row.localFileNames.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    Text(row.localFileNames)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .help(row.localFileNames)
                }
            }
            .width(min: 250, ideal: 420)

            TableColumn(localized("Status", "Status")) { row in
                StatusBadge(status: row.comparison.status)
            }
            .width(min: 118, ideal: 150, max: 180)

            TableColumn(localized("Hinweis", "Note")) { row in
                Text(row.comparison.note ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .width(min: 150, ideal: 250)
        }
        .alternatingRowBackgrounds(.enabled)
    }

    private var safetyNotice: some View {
        Label(localized("Die App analysiert nur den ausgewählten Ordner. Sie benennt, verschiebt, löscht oder lädt keine Dateien herunter.", "The app only analyzes the selected folder. It never renames, moves, deletes, or downloads files."), systemImage: "lock.shield")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
    }

    private var seriesSelectionPresented: Binding<Bool> {
        Binding(
            get: { !viewModel.candidates.isEmpty },
            set: { if !$0 { viewModel.dismissSeriesSelection() } }
        )
    }
}

private struct HistoryRow: View {
    let row: ScanHistoryRow
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: row.result == nil ? "exclamationmark.circle" : "checkmark.circle")
                .foregroundStyle(row.result == nil ? .orange : .green)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.seriesName ?? URL(fileURLWithPath: row.folderPath).lastPathComponent)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                Text(row.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(row.scannedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

private struct ResultHeader: View {
    let result: ScanResult
    let folderURL: URL?
    let notice: String?
    @Binding var filter: ResultFilter
    @Binding var selectedSeason: Int?
    let availableSeasons: [Int]
    let onChooseFolder: () -> Void
    let onChooseDifferentSeries: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(result.series.name).font(.title2.bold())
                    HStack(spacing: 8) {
                        Label("TVmaze", systemImage: "network")
                        if let folderURL {
                            Label(folderURL.lastPathComponent, systemImage: "folder")
                        }
                        Label(result.scannedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button(localized("Serie ändern", "Change series"), action: onChooseDifferentSeries)
                        .buttonStyle(.bordered)
                    Picker(localized("Staffel", "Season"), selection: $selectedSeason) {
                        Text(localized("Alle Staffeln", "All seasons")).tag(Int?.none)
                        ForEach(availableSeasons, id: \.self) { season in
                            Text(season == 0 ? localized("Specials", "Specials") : localized("Staffel \(season)", "Season \(season)")).tag(Optional(season))
                        }
                    }
                    .frame(width: 150)
                    Picker(localized("Filter", "Filter"), selection: $filter) {
                        ForEach(ResultFilter.allCases) { filter in
                            Text(filter.localizedDescription).tag(filter)
                        }
                    }
                    .frame(width: 155)
                }
            }

            HStack {
                Button(action: onChooseFolder) {
                    Label(localized("Anderen Serienordner auswählen", "Choose another series folder"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }

            HStack(spacing: 10) {
                SummaryCard(title: localized("Vollständig", "Complete"), value: result.summary.completeSeasons, tint: .green, symbol: "checkmark.circle.fill")
                SummaryCard(title: localized("Fehlend", "Missing"), value: result.summary.missing, tint: .red, symbol: "minus.circle.fill")
                SummaryCard(title: localized("Doppelt", "Duplicates"), value: result.summary.duplicates, tint: .orange, symbol: "plus.circle.fill")
                SummaryCard(title: localized("Manuell prüfen", "Manual review"), value: result.summary.manualReview, tint: .purple, symbol: "questionmark.circle.fill")
                SummaryCard(title: localized("Unveröffentlicht", "Unreleased"), value: result.summary.unreleased, tint: .blue, symbol: "clock.fill")
            }

            if let notice {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(18)
    }
}

private struct SummaryCard: View {
    let title: String
    let value: Int
    let tint: Color
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.title3.bold()).monospacedDigit()
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 118, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct StatusBadge: View {
    let status: EpisodeStatus

    var body: some View {
        Text(status.localizedDescription)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .present, .presentWithTitleDifference: .green
        case .missing: .red
        case .duplicate: .orange
        case .manualReview: .purple
        case .unreleased: .blue
        case .special: .secondary
        }
    }
}

private struct ProgressOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text(message).font(.callout)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(localized("Prüfung läuft", "Check in progress")): \(message)")
    }
}

private struct SeriesSelectionSheet: View {
    let candidates: [TVMazeShow]
    let onSelect: (TVMazeShow) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Passende Serie auswählen", "Choose the matching series")).font(.title2.bold())
            Text(localized("TVmaze hat mehrere mögliche Serien gefunden. Die Auswahl wird dauerhaft mit diesem Ordner verknüpft.", "TVmaze found several possible series. Your choice will be permanently linked to this folder."))
                .foregroundStyle(.secondary)
            List(candidates) { show in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(show.name).fontWeight(.semibold)
                        Text([show.premiered, show.language].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(localized("Auswählen", "Select")) {
                        onSelect(show)
                        dismiss()
                    }
                }
                .padding(.vertical, 4)
            }
            HStack {
                Spacer()
                Button(localized("Abbrechen", "Cancel")) {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 460)
    }
}
