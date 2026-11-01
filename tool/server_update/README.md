# RyzomCore4: Windows-Server-Update

Das GitHub-Actions-Paket ersetzt ausschliesslich Server-EXE/DLL-Dateien in
`E:\RyzomCore4-QuickStart\build_win32\server_dev\bin\Release`.

## Installation

1. Den Shard **sauber herunterfahren** (Mainland / Ring / Unifier).
2. Das **vollstaendige** GitHub-Artifact-ZIP in einen eigenen Ordner entpacken.
3. `Server-Update.bat` doppelklicken, Zusammenfassung lesen und bestaetigen.
4. Shard wieder starten und die Dienste und das Einloggen mit Testcharakter pruefen.
5. Falls die neuen Server-Binaries im Spiel Probleme verursachen: Shard wieder
   stoppen und `Server-Rollback.bat` doppelklicken. Das Skript verwendet
   nur ein zu der installierten Version passendes Update-Backup und sichert
   vorher den aktuellen Zustand erneut.

Der Installer hat ohne Bestaetigung keine Schreibwirkung. Beim allerersten
Update eines fremden/alten Serverstands fordert er zusaetzlich `ALTSTAND`.
Er prueft SHA256-Dateihashes, benoetigte EXEs und laufende Prozesse.
Er legt ein rueckspielbares Backup **nur der ersetzten Dateien** unter
`E:\RyzomCore4-QuickStart\update-backup\server-updates` an und versucht
bei Kopierfehlern automatisch zurueckzurollen. Ein Backup der Datenbanken
wird nicht erzeugt. Web-Dateien, Client, Datenbanken und Konfigurationen
werden durch das Skript nicht geaendert.

**Achtung:** Ein erfolgreiches Kopieren garantiert weder die
Kompatibilitaet eines alten 2022-Shards mit neueren EXEs noch ein
funktionierendes Datenbankschema. Ausserdem kann der Shard Binaries
aus anderen Verzeichnissen starten. Diese muessen zuerst anhand der
Quick-Start-Servicekonfiguration verifiziert werden. Dieses Paket
ist KEIN vollstaendiges automatisches Shard-Migrationswerkzeug.

Bei Fehlern die bisherigen Backups behalten und die Fehlermeldung melden.
Die alten Servicepakete/DBs niemals automatisch loeschen oder zuruecksetzen.
