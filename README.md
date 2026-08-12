# Serien-Vollständigkeitsprüfer

[Deutsch](#deutsch) · [English](#english)

## Deutsch

Eine native SwiftUI-App für macOS 14 oder neuer. Sie prüft einen bewusst ausgewählten Serienordner ausschließlich lesend gegen die Episodenliste von [TVmaze](https://www.tvmaze.com/).

### Funktionen

- Rekursiver Scan von Staffelordnern wie `S01`, `Staffel 1`, `Season 01` oder `01`.
- Berücksichtigt ausschließlich übliche Videoformate, darunter MKV, MP4, M4V, AVI, MOV, WMV, WebM, MPEG und TS/M2TS.
- Ignoriert Untertitel, Bilder, Archive, Metadaten und AppleDouble-Dateien (`._…`).
- Erkennt Serien anhand des gewählten Stammordners und – bei technischen Ordnernamen – vorrangig anhand der wiederkehrenden Dateinamen.
- Vergleicht verbindlich über Staffel- und Folgennummer. Eine explizite Kennzeichnung wie `S04E01` im Dateinamen hat Vorrang; der Staffelordner ist der Fallback für Namen ohne Staffelnummer.
- Meldet vorhandene, fehlende, doppelte, unveröffentlichte und manuell zu prüfende Folgen sowie Specials.
- Erkennt lokale Schreibweisen mit Umlauten und Umschreibungen wie `Ä/Ae`, `Ö/Oe` und `Ü/Ue` bei der Dateinamenerkennung.
- Lokaler TVmaze-Cache für sieben Tage mit Offline-Fallback.
- Dauerhafte Serienzuordnung und Scanverlauf via SwiftData.
- Text- und CSV-Export des vollständigen Scanergebnisses.
- Umschaltbare Benutzeroberfläche: Deutsch oder English über das Globus-Menü in der Symbolleiste.

### Verwendung

1. App starten und **Serienordner auswählen**.
2. Den Serien-Stammordner wählen; darin können die Staffelordner liegen.
3. **Ordner prüfen** drücken und, falls nötig, die passende TVmaze-Serie bestätigen.
4. Für eine zuvor falsch gespeicherte Zuordnung im Menü **Mehr** → **Andere Serie auswählen** wählen.

### Datenschutz und Sicherheit

Die App analysiert ausschließlich den ausgewählten Ordner. Sie benennt keine Dateien um, verschiebt oder löscht keine Dateien und lädt keine Medien herunter. Für den Online-Abgleich wird nur eine TVmaze-Suche mit dem erkannten Seriennamen ausgeführt.

### Voraussetzungen und Entwicklung

- macOS 14+
- Xcode mit Swift 6

```sh
swift test
open SerienVollstaendigkeitspruefer.xcodeproj
```

Die App-Sandbox erlaubt nur benutzerausgewählten Lesezugriff und Netzwerkzugriff auf TVmaze. Für eine signierte lokale Debug-App muss ein Apple-Development-Zertifikat in Xcode verfügbar sein.

## English

A native SwiftUI app for macOS 14 and later. It compares one deliberately selected series folder in read-only mode with the episode list from [TVmaze](https://www.tvmaze.com/).

### Features

- Recursively scans season folders such as `S01`, `Staffel 1`, `Season 01`, or `01`.
- Considers only common video formats including MKV, MP4, M4V, AVI, MOV, WMV, WebM, MPEG, and TS/M2TS.
- Ignores subtitles, images, archives, metadata, and AppleDouble files (`._…`).
- Identifies the series from the selected root folder and, when the folder name is technical, gives repeated video filenames priority.
- Compares strictly by season and episode number. An explicit filename marker such as `S04E01` wins; the season folder is a fallback for filenames without a season number.
- Reports present, missing, duplicate, unreleased, and manual-review episodes, plus specials.
- Recognizes local filename spellings with umlauts and alternatives such as `Ä/Ae`, `Ö/Oe`, and `Ü/Ue`.
- Seven-day local TVmaze cache with an offline fallback.
- Persistent series assignment and scan history using SwiftData.
- Text and CSV exports of the complete scan result.
- Switchable interface: German or English through the globe menu in the toolbar.

### Usage

1. Launch the app and choose **Choose series folder**.
2. Select the series root folder; it may contain the season subfolders.
3. Select **Check folder** and confirm the matching TVmaze series when prompted.
4. To fix a previously saved incorrect assignment, use **More** → **Choose a different series**.

### Privacy and safety

The app analyzes only the selected folder. It never renames, moves, or deletes files, and it never downloads media. The online comparison only sends the detected series name to a TVmaze search request.

### Requirements and development

- macOS 14+
- Xcode with Swift 6

```sh
swift test
open SerienVollstaendigkeitspruefer.xcodeproj
```

The app sandbox allows only user-selected read access and network access to TVmaze. Building a signed local debug app requires an Apple Development certificate in Xcode.
