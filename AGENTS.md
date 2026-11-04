# Projektanweisungen

<!-- skill-routing:start v1 – gepflegt mit ~/.claude/skill-routing/skill_routing.py; gemeinsame Regeln in AGENTS.md; CLAUDE.md bindet sie ein -->
## Skill-Zuordnung

Projektart: Native Apple-App (Xcode/Swift, SwiftUI).

| Wann | Skill |
| --- | --- |
| Vor Release, Archiv, TestFlight-Upload, App-Store-Einreichung oder vor größeren Änderungen | `apple-app-release-check` (ohne ausdrücklichen Auftrag nur Stufe „Prüfen“) |
| SwiftUI-Ansichten schreiben, prüfen, umbauen; Performance; Instruments-Traces | `swiftui-expert-skill` |
| async/await, Actors, `Sendable`, `@MainActor`, Swift-6-Warnungen | `swift-concurrency` |
| Nur auf ausdrücklichen Wunsch: fremde App analysieren oder nachbauen | `replica-*` (Start: `replica-recon`) |

Nicht zuständig: `playwright` (keine Weboberfläche; native Oberflächen mit Simulator/Xcode prüfen).

Skills nur verwenden, wenn die Aufgabe dazu passt; die globale Regel gilt zusätzlich.
In Claude Code heißen die Plugin-Skills `swiftui-expert:swiftui-expert-skill` und `swift-concurrency:swift-concurrency`.
<!-- skill-routing:end -->
