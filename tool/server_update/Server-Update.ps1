# Ryzom QuickStart binary update - PowerShell 5.1 compatible.
# Run only after extracting the ZIP from GitHub Actions. The server must be stopped.
param(
    [string]$Root = 'E:\RyzomCore4-QuickStart'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Update([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$package = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $package 'server-bin'
$manifestFile = Join-Path $package 'manifest.json'
$backup = $null
$written = @()
$existing = @{}
$markerBackup = $false
$target = $null

try {
    Assert-Update (Test-Path -LiteralPath $manifestFile -PathType Leaf) 'manifest.json fehlt. ZIP bitte zuerst komplett entpacken.'
    Assert-Update (Test-Path -LiteralPath $source -PathType Container) 'server-bin fehlt. ZIP bitte zuerst komplett entpacken.'

    $manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Update ($manifest.schema -eq 1) 'Unbekanntes Paketformat.'
    Assert-Update ($manifest.platform -eq 'windows-x64') 'Dieses Paket ist nicht fuer Windows x64.'
    Assert-Update ($manifest.repository -eq 'wdcyvk8v26-debug/ryzomcore') 'Paket stammt nicht aus dem erwarteten RyzomCore-Fork.'
    Assert-Update ($manifest.commit -match '^[0-9a-f]{40}$') 'Ungueltige Build-ID.'
    $files = @($manifest.files)
    Assert-Update ($files.Count -ge 5) 'Zu wenige Binaries: unvollstaendiges Serverpaket.'
    $names = @{}
    foreach ($entry in $files) {
        $name = [string]$entry.name
        Assert-Update ($name -cmatch '^[A-Za-z0-9_.-]+\.(exe|dll)$') "Ungueltiger Dateiname: $name"
        Assert-Update (-not $names.ContainsKey($name.ToLowerInvariant())) "Doppelte Datei: $name"
        $names[$name.ToLowerInvariant()] = $true
        Assert-Update ([string]$entry.sha256 -match '^[0-9a-fA-F]{64}$') "Fehlende Pruefsumme: $name"
        $file = Join-Path $source $name
        Assert-Update (Test-Path -LiteralPath $file -PathType Leaf) "Datei fehlt: $name"
        Assert-Update ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ieq $entry.sha256) "Pruefsumme falsch: $name"
    }
    foreach ($required in @('ryzom_entities_game_service.exe', 'ryzom_frontend_service.exe', 'ryzom_naming_service.exe')) {
        Assert-Update ($names.ContainsKey($required)) "Kritische Server-EXE fehlt: $required"
    }

    $Root = [IO.Path]::GetFullPath($Root)
    Assert-Update (Test-Path -LiteralPath (Join-Path $Root 'pipeline\shard_dev') -PathType Container) "Kein QuickStart-Shard unter: $Root"
    Assert-Update (Test-Path -LiteralPath (Join-Path $Root 'build_win32') -PathType Container) 'QuickStart-build_win32 fehlt.'
    $target = Join-Path $Root 'build_win32\server_dev\bin\Release'
    # No silent diversion to another client or build directory.
    Write-Host ""
    Write-Host 'Ryzom Core4 Server-Update' -ForegroundColor Cyan
    Write-Host "Paket:  $($manifest.commit)"
    Write-Host "Quelle: $($manifest.repository) ($($manifest.branch))"
    Write-Host "Ziel:   $target"
    Write-Host "Dateien: $($files.Count) EXE/DLL"
    Write-Host ""

    # Never replace executables while ANY shard service is running.
    $running = @(Get-CimInstance Win32_Process | Where-Object {
        ($_.Name -match '^(ryzom_|nelns_|admin_executor_service).*\.exe$') -or
        ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase))
    })
    if ($running.Count -gt 0) {
        $running | Select-Object Name, ProcessId, ExecutablePath | Format-Table -AutoSize
        throw 'Serverdienste laufen noch! Erst ueber die Dashboards herunterfahren. Keine Prozesse werden automatisch beendet.'
    }

    $marker = Join-Path $target 'RYZOM_SERVER_UPDATE.json'
    if ((Test-Path -LiteralPath $target -PathType Container) -and
        -not (Test-Path -LiteralPath $marker -PathType Leaf) -and
        @(Get-ChildItem -LiteralPath $target -Filter '*.exe' -File).Count -gt 0) {
        Write-Warning 'Der bisherige Server hat keinen Update-Marker. Er kann aus 2022 stammen.'
        Write-Warning 'Es koennen Datenbank- und Konfigurationsmigrationen erforderlich sein.'
        $confirmation = Read-Host 'Zum erstmaligen Uebernehmen ALTSTAND eingeben (sonst Abbruch)'
        Assert-Update ($confirmation -ceq 'ALTSTAND') 'Abgebrochen. Alte Installation wurde nicht veraendert.'
    }
    $approval = Read-Host 'Server-EXEs sichern und ersetzen? JA eingeben (sonst Abbruch)'
    Assert-Update ($approval -ceq 'JA') 'Abgebrochen. Keine Dateien wurden geaendert.'

    # Keep backups out of the main build folder; preserve existing DB/config/client.
    $backupBase = Join-Path $Root 'update-backup\server-updates'
    New-Item -ItemType Directory -Path $backupBase -Force | Out-Null
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $manifest.commit.Substring(0, 8)
    $backup = Join-Path $backupBase $stamp
    Assert-Update (-not (Test-Path -LiteralPath $backup)) 'Backupordner existiert bereits.'
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    foreach ($entry in $files) {
        $destination = Join-Path $target ([string]$entry.name)
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            Copy-Item -LiteralPath $destination -Destination (Join-Path $backup $entry.name) -ErrorAction Stop
            $existing[$entry.name] = $true
        }
    }
    if (Test-Path -LiteralPath $marker -PathType Leaf) {
        Copy-Item -LiteralPath $marker -Destination (Join-Path $backup 'RYZOM_SERVER_UPDATE.json') -ErrorAction Stop
        $markerBackup = $true
    }

    # Verify ALL incoming files before touching the installation.
    foreach ($entry in $files) {
        $name = [string]$entry.name
        $destination = Join-Path $target $name
        Copy-Item -LiteralPath (Join-Path $source $name) -Destination $destination -Force -ErrorAction Stop
        $written += $name
        Assert-Update ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ieq $entry.sha256) "Kopierfehler: $name"
    }
    Copy-Item -LiteralPath $manifestFile -Destination $marker -Force -ErrorAction Stop
    Write-Host ""
    Write-Host 'UPDATE ERFOLGREICH' -ForegroundColor Green
    Write-Host "Backup: $backup"
    Write-Host 'Jetzt Web / Unifier / Mainland / Ring kontrolliert starten und testen.'
    exit 0
}
catch {
    Write-Host ""
    Write-Host "ABBRUCH: $($_.Exception.Message)" -ForegroundColor Red
    if ($written.Count -gt 0 -and $backup -and $target) {
        Write-Warning 'Kopieren schlug fehl: Wiederherstellung der zuvor vorhandenen Dateien...'
        foreach ($name in $written) {
            $destination = Join-Path $target $name
            try {
                if ($existing.ContainsKey($name)) {
                    Copy-Item -LiteralPath (Join-Path $backup $name) -Destination $destination -Force -ErrorAction Stop
                } elseif (Test-Path -LiteralPath $destination) {
                    Remove-Item -LiteralPath $destination -Force -ErrorAction Stop
                }
            } catch {
                Write-Warning ("Rollback unvollstaendig fuer " + $name + ": " + $_.Exception.Message)
            }
        }
        try {
            $marker = Join-Path $target 'RYZOM_SERVER_UPDATE.json'
            if ($markerBackup) {
                Copy-Item -LiteralPath (Join-Path $backup 'RYZOM_SERVER_UPDATE.json') -Destination $marker -Force
            } elseif (Test-Path -LiteralPath $marker) {
                Remove-Item -LiteralPath $marker -Force
            }
        } catch { Write-Warning 'Update-Marker konnte nicht zurueckgesetzt werden.' }
        Write-Warning ("Backup: " + $backup)
    }
    exit 1
}
