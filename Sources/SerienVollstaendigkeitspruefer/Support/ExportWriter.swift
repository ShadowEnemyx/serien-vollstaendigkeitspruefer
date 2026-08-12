import AppKit
import Foundation

@MainActor
enum ExportWriter {
    static func exportText(_ result: ScanResult) throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(safeFileName(result.series.name))-\(localized("Prüfung", "Check")).txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try textReport(result).write(to: url, atomically: true, encoding: .utf8)
    }

    static func exportCSV(_ result: ScanResult) throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(safeFileName(result.series.name))-\(localized("Prüfung", "Check")).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try csvReport(result).write(to: url, atomically: true, encoding: .utf8)
    }

    static func textReport(_ result: ScanResult) -> String {
        var lines = [result.series.name, "\(localized("Prüfung", "Check")): \(result.scannedAt.formatted(date: .long, time: .shortened))", ""]
        for season in result.seasons {
            let heading = season.season == 0 ? localized("Specials", "Specials") : season.season < 0 ? localized("Manuell prüfen", "Manual review") : localized("Staffel \(season.season)", "Season \(season.season)")
            lines.append(heading)
            for comparison in season.comparisons {
                let number = comparison.episode.map { String(format: "E%02d", $0) } ?? "—"
                let names = comparison.files.map(\.fileName).joined(separator: " | ")
                lines.append("  \(number): \(comparison.status.localizedDescription)\(comparison.expectedTitle.map { " – \($0)" } ?? "")\(names.isEmpty ? "" : " – \(names)")")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func csvReport(_ result: ScanResult) -> String {
        let header = [
            localized("Serie", "Series"),
            localized("Staffel", "Season"),
            localized("Folge", "Episode"),
            localized("Erwarteter Titel", "Expected title"),
            localized("Lokale Datei", "Local file"),
            localized("Status", "Status"),
            localized("Hinweis", "Note")
        ]
        var rows = [header]
        for comparison in result.seasons.flatMap(\.comparisons) {
            let files = comparison.files.isEmpty ? [""] : comparison.files.map(\.fileName)
            for file in files {
                rows.append([
                    result.series.name,
                    comparison.season.map(String.init) ?? "",
                    comparison.episode.map(String.init) ?? "",
                    comparison.expectedTitle ?? "",
                    file,
                    comparison.status.localizedDescription,
                    comparison.note ?? ""
                ])
            }
        }
        return rows.map { $0.map(escapeCSV).joined(separator: ";") }.joined(separator: "\n")
    }

    private static func escapeCSV(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func safeFileName(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-")
    }
}
