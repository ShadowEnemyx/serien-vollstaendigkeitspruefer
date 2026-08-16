# KI-Kontext: Serien-Vollständigkeitsprüfer

> Diese Datei ist der Einstiegspunkt für eine andere KI oder Entwicklerin/einen anderen Entwickler. Sie beschreibt den aktuellen Stand, getroffene Entscheidungen und die nächsten sinnvollen Arbeiten. Vor einer Änderung immer auch `README.md`, den betroffenen Quellcode und `git status -sb` lesen.

## Zweck der App

**Serien-Vollständigkeitsprüfer** ist eine native SwiftUI-App für macOS 14+. Sie analysiert einen vom Benutzer ausgewählten Serien-Stammordner **ausschließlich lesend**. Lokale Videodateien werden anhand von Staffel- und Episodennummern mit der Episodenliste von TVmaze verglichen.

Das Produktversprechen darf nicht verwässert werden:

- Niemals Dateien umbenennen, verschieben, löschen oder Medien herunterladen.
- Nur einen ausdrücklich im Finder ausgewählten Ordner lesen.
- Die App-Sandbox beibehalten; keine umfassenden Dateirechte hinzufügen.
- Einen verständlichen, dauerhaft sichtbaren Read-only-Hinweis in der Oberfläche beibehalten.

## Aktueller Stand

- Projektordner: `/Volumes/2TB SSD/Backup bot/Apps/serien_folgen_finder`
- Öffentliche Quelle: <https://github.com/ShadowEnemyx/serien-vollstaendigkeitspruefer>
- Hauptzweig: `main`
- Aktuellen Commit immer mit `git log -1 --oneline` prüfen; diese Datei wird zusammen mit Funktionsänderungen gepflegt.
- Lokale ausführbare App: `/Users/shadowenemy/Desktop/Serien-Vollständigkeitsprüfer.app`
- Lokales Debug-ZIP: `dist/SerienVollstaendigkeitspruefer-Debug.app.zip` (absichtlich nicht versioniert)
- Toolchain: Xcode mit Swift 6; Deployment Target macOS 14.
- Tests: aktuell 21 Unit-Tests grün (`swift test`; der Xcode-Runner kann in dieser Arbeitsumgebung gelegentlich ohne aktiven Unterprozess hängen).

## Nutzeranforderungen, die bereits umgesetzt sind

### Ordnerstruktur und Scan

- Es wird **ein Serien-Stammordner pro Prüfung** gewählt.
- Unterordner werden rekursiv gescannt, insbesondere Staffelordner wie `S01`, `S02`, `Staffel 1`, `Season 01` oder `01`.
- Nur gängige Videoformate werden berücksichtigt: `mkv`, `mp4`, `m4v`, `avi`, `mov`, `wmv`, `webm`, `flv`, `ogv`, `ts`, `m2ts`, `mts`, `mpg`, `mpeg`, `vob`, `3gp`, `3g2`.
- Keine Untertitel, Bilder, NFO-Dateien, Archive oder sonstige Begleitdateien scannen.
- AppleDouble-Dateien auf externen Datenträgern (`._Dateiname.mkv`) sind zwingend zu ignorieren.
- Symbolische Links und Paketordner dürfen nicht verfolgt werden.
- Der Scan läuft außerhalb des Main Actors und kann abgebrochen werden.

### Erkennung von Staffel, Folge und Serie

- Eine explizite Dateinamenkennung wie `S04E01` hat Vorrang vor dem Ordnernamen. Deshalb darf `S04E01` unter einem versehentlich falschen `S01`-Ordner **nicht** als Dublette von `S01E01` zählen.
- Für die Episodenerkennung werden alle Sonderzeichen wie Leerzeichen behandelt. Daher müssen Staffeln und Folgen auch in Release-Namen wie `S.01.E.02`, `S_01__E_02`, `S-01-E-02` oder `[Season-01][Episode_02]` erkannt werden.
- Wenn im Dateinamen keine Staffel steht, dient der unmittelbare Staffelordner als Fallback.
- Mehrteilige Dateien, Staffelpacks, Zusatzmaterial, unklare Namen und nicht parsebare Namen landen unter „Manuell prüfen“.
- Dateien mit Begriffen wie `sample`, `trailer`, `extra`, `featurette`, `behind the scenes` und `interview` werden nicht regulär verglichen, bleiben aber sichtbar.
- Bei technischen Stammordnern (z. B. `TEST_MARV`) haben wiederkehrende Seriennamen aus Videodateien Vorrang vor dem Stammordnernamen.
- Bei der Textnormalisierung Umlaute/Akzente robust behandeln, z. B. `Ä/Ae`, `Ö/Oe`, `Ü/Ue`; keine Episode allein wegen einer Titel-Schreibvariante als „Manuell prüfen“ ausweisen.
- Für TVmaze-Suchtreffer werden Treffer anhand lokaler Namensbestandteile bewertet. Das verhindert offensichtliche Falschzuordnungen wie „Mary Knows Best“ für Marvel’s Agents of S.H.I.E.L.D.

### Vergleichslogik

Statuswerte sind in `EpisodeStatus` definiert:

- vorhanden
- vorhanden, Titel abweichend
- fehlt
- doppelt
- manuell prüfen
- noch nicht veröffentlicht
- Special

Der Vergleich ist über **Staffel- und Folgennummer** verbindlich. Abweichende Titel sind ein Hinweis, aber niemals ein Fehlend-Status. Noch nicht ausgestrahlte reguläre Episoden und Staffel 0/Specials zählen nicht als fehlend.

### TVmaze, Speicherung und Offline-Verhalten

- Suche: `GET /search/shows`
- Episoden: `GET /shows/{id}/episodes?specials=1`
- SwiftData speichert Serienzuordnung, Scanverlauf und TVmaze-Cache.
- Der Cache ist sieben Tage gültig.
- „TVmaze-Daten aktualisieren“ ignoriert den Cache.
- Bei Offline-Betrieb wird ein abgelaufener Cache verwendet, wenn vorhanden; ohne Cache bleiben lokale Daten sichtbar und der Online-Fehler wird erklärt.
- Eine einmal bestätigte TVmaze-Serie ist dauerhaft an den lokalen Ordner gebunden. Über „Mehr“ → „Andere Serie auswählen“ kann diese Zuordnung entfernt werden.

### NAS, Netzlaufwerke und externe Datenträger

- Über Finder eingehängte SMB-, AFP- und NFS-Freigaben funktionieren als ausgewählter Serienordner.
- Der Scan prüft vor dem Traversieren, ob der Wurzelordner erreichbar, ein Ordner und lesbar ist.
- Eine getrennte NAS-Freigabe darf nie irreführend als leerer Ordner erscheinen; es muss ein konkreter Verbindungs- bzw. Rechtefehler angezeigt werden.
- Nicht lesbare Unterpfade werden übersprungen und über die Anzahl in der Oberfläche gemeldet.
- Sehr große oder langsame NAS-Freigaben können den Scan verlangsamen, blockieren aber nicht die Benutzeroberfläche. Ein Abbruch ist möglich.

### Oberfläche

- Native SwiftUI-Oberfläche mit Sidebar, Ergebnisheader, Kennzahlen, Staffelwahl, Statusfilter und Episodentabelle.
- Ordnerauswahl und „Ordner prüfen“ sind im Startzustand mittig sichtbar.
- Nach einem erfolgreichen Scan bleibt im Ergebnisheader dauerhaft der primäre Button **„Anderen Serienordner auswählen“** sichtbar. Dieser war zuvor fälschlich nicht erreichbar und darf nicht wieder entfernt werden.
- Die Symbolleiste enthält ein „Mehr“-Menü (TVmaze neu laden, Serie ändern, Exporte) und ein Globus-Menü zur Sprachauswahl.
- Die sichtbare App-Sprache kann im Globus-Menü zwischen **Deutsch** und **English** wechseln. Die Einstellung liegt in `UserDefaults` unter `appLanguage`.
- Text- und CSV-Export enthalten immer das gesamte aktuelle Ergebnis, unabhängig vom aktiven Filter.

### Icon und Auslieferung

- Das App-Icon befindet sich im Asset-Katalog `Sources/SerienVollstaendigkeitspruefer/Assets.xcassets/AppIcon.appiconset`.
- Es ist ein dunkles, blaues Filmrollen-Icon mit türkisfarbenem Haken und goldgelbem Akzent; alle macOS-Größen liegen im Katalog vor.
- `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` ist im Xcode-Projekt gesetzt.
- Die Desktop-App wurde lokal mit dem vorhandenen Apple-Development-Zertifikat signiert und danach mit `codesign --verify --deep --strict` geprüft.

## Architektur und zentrale Dateien

```text
Sources/SerienVollstaendigkeitspruefer/
├── SerienVollstaendigkeitsprueferApp.swift    App-Einstieg, SwiftData-Container
├── Views/ContentView.swift                    gesamte SwiftUI-Hauptoberfläche
├── ViewModels/ScanViewModel.swift             @MainActor-Koordination von UI, Scan, API und Persistenz
├── Services/
│   ├── FileScanner.swift                      rekursiver, lesender Video-Scan + NAS-Prüfung
│   ├── EpisodeParser.swift                    Dateiname/Staffelordner → Staffel und Folge
│   ├── EpisodeComparator.swift                lokaler/online Episodenvergleich
│   ├── SeriesMatcher.swift                    Suchbegriffe und Ranking von TVmaze-Treffern
│   ├── TVMazeClient.swift                     URLSession, Cache, Offline-Fallback
│   └── FolderAccessManager.swift              security-scoped Bookmarks
├── Domain/Models.swift                        reine Domain-Typen und Statuswerte
├── Persistence/PersistenceModels.swift        SwiftData-Modelle
├── Support/AppLanguage.swift                  Deutsch/English-Helfer
└── Support/ExportWriter.swift                 Text- und CSV-Export

Tests/SerienVollstaendigkeitsprueferTests/     Unit-Tests
```

Wichtige öffentliche bzw. fachliche Schnittstellen:

```swift
FileScanner.scan(folderURL:) async throws -> FileScanOutput
EpisodeParser.parse(fileName:) -> EpisodeParseResult
TVMazeClient.searchShows(query:) async throws -> [TVMazeShow]
TVMazeClient.loadEpisodes(showID:forceRefresh:) async throws -> [OnlineEpisode]
EpisodeComparator.compare(localFiles:onlineEpisodes:series:) -> ScanResult
```

`ScanViewModel` ist das einzige Bindeglied zwischen SwiftUI, Persistenz und den Fachkomponenten. Fachlogik nicht unnötig in `ContentView` verschieben.

## Sicherheits- und Persistenzregeln

- Entitlements in `SerienVollstaendigkeitspruefer.entitlements`:
  - App Sandbox aktiviert
  - nur benutzerausgewählter **Lesezugriff**
  - ausgehender Netzwerkzugriff für TVmaze
- Nach Ordnerauswahl wird ein security-scoped Bookmark gespeichert.
- Vor einem Scan wird `startAccessingSecurityScopedResource()` aufgerufen und danach zuverlässig beendet.
- Gespeicherte Bookmarks können veralten (Laufwerk/NAS getrennt oder umbenannt). In dem Fall keinen Zugriff erzwingen, sondern erneute Ordnerauswahl verlangen.
- Keine Zugangsdaten, NAS-Passwörter oder private Pfade in Git, Berichte oder Netzwerkaufrufe schreiben.

## Validierung und lokales Bauen

Im Projektordner:

```sh
swift test
xcodebuild -project 'SerienVollstaendigkeitspruefer.xcodeproj' \
  -scheme 'Serien-Vollständigkeitsprüfer' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO test
```

Für eine signierte Desktop-Debug-App wurde zuletzt sinngemäß dieser Ablauf verwendet:

```sh
xcodebuild -project 'SerienVollstaendigkeitspruefer.xcodeproj' \
  -scheme 'Serien-Vollständigkeitsprüfer' \
  -configuration Debug \
  CONFIGURATION_BUILD_DIR='/tmp/serien-release-build' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Development: Adrian Herbst (Z8Z6L48995)' \
  DEVELOPMENT_TEAM='6R6S2SH2U2' build

codesign --verify --deep --strict --verbose=2 \
  '/tmp/serien-release-build/SerienVollstaendigkeitspruefer.app'
```

Die gebaute App mit `ditto` auf den Schreibtisch kopieren, nicht mit einem unsicheren Rekursivbefehl überschreiben. Vorher eine laufende App sauber beenden. Das ZIP mit `ditto -c -k --sequesterRsrc --keepParent` erzeugen und anschließend mit `unzip -t` prüfen.

## Git-Regeln

- Repository und Remote: `origin` → `https://github.com/ShadowEnemyx/serien-vollstaendigkeitspruefer.git`
- Nur beabsichtigte Dateien stagen; keine pauschalen `git add -A`-Befehle bei unklarem Arbeitsbaum.
- `.gitignore` schließt Build-Ausgaben, `dist/`, `xcuserdata/`, `.DS_Store` und AppleDouble-Dateien `._*` aus.
- Das Projekt liegt auf einem externen Datenträger. Dadurch können viele `._*`-Dateien entstehen. Sie sind macOS-Metadaten, keine Quellcodeänderungen und dürfen niemals eingecheckt werden.
- Vor Commits `git diff --check` und mindestens `swift test` ausführen.
- Für neue öffentliche Änderungen README und diese Kontextdatei aktualisieren, wenn sich Verhalten oder Architektur ändern.

## Bekannte Grenzen (bewusst noch nicht umgesetzt)

1. Pro Vorgang wird genau ein Serien-Stammordner geprüft. Mehrere Serienordner gleichzeitig oder eine komplette Bibliothek sind nicht implementiert.
2. Ein Ordner entspricht genau einer TVmaze-Serie. Es gibt keine manuelle Umrechnung von Staffelnummern.
3. Die App bietet keine automatische/zeitgesteuerte Prüfung.
4. Keine eingebauten Release-Downloads auf GitHub und noch keine CI-Pipeline.
5. Es gibt noch keine formale Open-Source-Lizenz. Bei einer Veröffentlichung zur Weiterverwendung mit dem Eigentümer abstimmen, ob z. B. MIT verwendet werden soll.
6. Die App kann auf einem echten NAS prüfen, aber ein vollwertiger Integrations-Test mit einer konkreten NAS-Freigabe wurde in dieser Arbeitsumgebung nicht ausgeführt.

## Sinnvolle nächste Schritte

Priorität vor allem nach Nutzerbedarf setzen:

1. **Test auf echtem NAS:** SMB-Freigabe auswählen, während eines Scans Verbindung trennen, Berechtigungsfehler testen, danach Verbindung wiederherstellen.
2. **Mehrfachordner-/Bibliotheksmodus:** erst als klar getrennte Erweiterung planen; jede Serie braucht eine eigene Zuordnung und eigenes Ergebnis, damit keine Folgen vermischt werden.
3. **Bessere TVmaze-Auswahl:** Falls weiterhin einzelne falsche Treffer entstehen, den Nutzer zusätzlich nach Erscheinungsjahr oder Sprache filtern lassen; niemals stillschweigend eine unsichere Zuordnung speichern.
4. **GitHub-Releases und CI:** automatische Tests mit GitHub Actions und signierte/notarisierte Releases erst nach Klärung von Apple-Developer- und Distributionszugang.
5. **Lizenz:** MIT oder eine andere bewusst ausgewählte Lizenz ergänzen, wenn andere den Code rechtssicher verwenden und beitragen sollen.

## Checkliste für jede künftige Änderung

- [ ] Read-only-Garantie und Sandbox bleiben erhalten.
- [ ] Dateien auf NAS, externen Datenträgern und lokalen Ordnern bleiben ausschließlich lesend.
- [ ] Staffelordner werden weiterhin rekursiv unterstützt.
- [ ] Keine Neben- oder AppleDouble-Dateien als Folgen erkennen.
- [ ] Explizite Staffelnummer im Dateinamen bleibt wichtiger als der Ordnername.
- [ ] Deutsch und English für neue sichtbare Texte ergänzen (`localized(de, en)`).
- [ ] Ordnerwechsel bleibt nach erfolgreichem Scan erreichbar.
- [ ] `swift test`, Xcode-Testlauf und `git diff --check` erfolgreich ausführen.
- [ ] Bei tatsächlicher App-Auslieferung Signatur und ZIP prüfen.
