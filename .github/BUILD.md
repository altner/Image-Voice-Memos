# DMG erstellen und auf GitHub veröffentlichen

## Voraussetzungen

- macOS 15.0+ auf Apple Silicon (M1 oder neuer)
- Xcode installiert und als aktives Developer-Verzeichnis gesetzt:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) installiert (`brew install xcodegen`)
- [GitHub CLI](https://cli.github.com/) installiert und authentifiziert (`brew install gh && gh auth login`)

## 1. DMG erstellen

```bash
./create-dmg.sh
```

Das Script:
1. Generiert das Xcode-Projekt via `xcodegen` (falls nötig)
2. Baut die App im Release-Modus (`xcodebuild`)
3. Erstellt ein DMG mit App + Applications-Symlink (`hdiutil`)

Das fertige DMG liegt unter `build/Image-Voice-Memos-v<VERSION>.dmg`.

### Version ändern

In `create-dmg.sh` die Variable `VERSION` anpassen:

```bash
VERSION="0.2.0"
```

Nicht vergessen, auch in `project.yml` und `Info.plist` die Version zu aktualisieren.

## 2. Neues Release auf GitHub erstellen

### Release Notes vorbereiten

Die Datei `.github/release-notes.md` mit den Installationsanweisungen und Changelog aktualisieren.

### Release erstellen und DMG hochladen

```bash
gh release create v0.1.1 build/Image-Voice-Memos-v0.1.1.dmg \
  --title "v0.1.1" \
  --notes-file .github/release-notes.md
```

### DMG nachträglich zu einem bestehenden Release hinzufügen

```bash
gh release upload v0.1.1 build/Image-Voice-Memos-v0.1.1.dmg
```

### Release Notes nachträglich aktualisieren

```bash
gh release edit v0.1.1 --notes-file .github/release-notes.md
```

## 3. Installationsanleitung für Nutzer

Da die App ohne Apple Developer Account gebaut wird, ist sie nicht notarisiert. Nutzer müssen Gatekeeper manuell umgehen:

1. DMG von GitHub Releases herunterladen
2. DMG öffnen, App nach `/Applications` ziehen
3. Terminal öffnen und ausführen:
   ```bash
   xattr -rd com.apple.quarantine /Applications/Image-Voice-Memos.app
   ```
   Hinweis: Terminal braucht ggf. "Full Disk Access" unter Systemeinstellungen > Datenschutz & Sicherheit.
4. App starten und Mikrofon- sowie Spracherkennungs-Berechtigungen erteilen
