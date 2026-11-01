# Restore the previous server EXE/DLL set after a test of the new version.
# This never touches databases, config or client files.
param([string]$Root = 'E:\RyzomCore4-QuickStart')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Rollback([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$oldBackup = $null
$safety = $null
$changed = @()
$markerTouched = $false

try {
    $Root = [IO.Path]::GetFullPath($Root)
    Assert-Rollback (Test-Path -LiteralPath (Join-Path $Root 'pipeline\shard_dev') -PathType Container) 'Kein Ryzom QuickStart-Shard.'
    $target = Join-Path $Root 'build_win32\server_dev\bin\Release'
    $backupBase = Join-Path $Root 'update-backup\server-updates'
    $marker = Join-Path $target 'RYZOM_SERVER_UPDATE.json'
    Assert-Rollback (Test-Path -LiteralPath $marker -PathType Leaf) 'Kein installiertes Update mit Versionsmarker gefunden.'
    Assert-Rollback (Test-Path -LiteralPath $backupBase -PathType Container) 'Kein Backupordner gefunden.'
    $current = Get-Content -LiteralPath $marker -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Rollback ($current.commit -match '^[0-9a-f]{40}$') 'Ungueltige installierte Versionskennung.'
    Assert-Rollback ($current.repository -eq 'wdcyvk8v26-debug/ryzomcore') 'Fremdes Updatepaket.'

    $running = @(Get-CimInstance Win32_Process | Where-Object {
        ($_.Name -match '^(ryzom_|nelns_|admin_executor_service).*\.exe$') -or
        ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase))
    })
    if ($running.Count -gt 0) {
        $running | Select-Object Name, ProcessId | Format-Table
        throw 'Serverdienste laufen noch. Erst sauber herunterfahren.'
    }

    # Find the most recent backup whose installed commit matches the current one.
    $candidates = @(Get-ChildItem -LiteralPath $backupBase -Directory | Sort-Object LastWriteTime -Descending)
    $meta = $null
    foreach ($candidate in $candidates) {
        $candidateInfo = Join-Path $candidate.FullName 'rollback.json'
        if (-not (Test-Path -LiteralPath $candidateInfo -PathType Leaf)) { continue }
        $info = Get-Content -LiteralPath $candidateInfo -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($info.schema -eq 1 -and $info.deployedCommit -eq $current.commit) {
            $meta = $info
            $oldBackup = $candidate.FullName
            break
        }
    }
    Assert-Rollback ($null -ne $meta) 'Kein passendes Backup fuer die installierte Version gefunden.'
    $installed = @($meta.installed)
    $previous = @{}
    foreach ($name in @($meta.previous)) { $previous[[string]$name] = $true }
    Assert-Rollback ($installed.Count -ge 5) 'Backupbeschreibung unvollstaendig.'

    $validFiles = @{}
    foreach ($entry in @($current.files)) {
        $validFiles[[string]$entry.name] = [string]$entry.sha256
    }
    foreach ($file in $installed) {
        $name = [string]$file
        Assert-Rollback ($name -cmatch '^[A-Za-z0-9_.-]+\.(exe|dll)$') "Ungueltiger Dateiname: $name"
        Assert-Rollback ($validFiles.ContainsKey($name)) "Installiertes Manifest enthaelt $name nicht."
        $path = Join-Path $target $name
        Assert-Rollback (Test-Path -LiteralPath $path -PathType Leaf) "Installierte Datei fehlt: $name"
        Assert-Rollback ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ieq $validFiles[$name]) "Installierte Datei wurde nach dem Update veraendert: $name"
        if ($previous.ContainsKey($name)) {
            Assert-Rollback (Test-Path -LiteralPath (Join-Path $oldBackup $name) -PathType Leaf) "Backup fehlt: $name"
        }
    }
    if ($meta.previousMarker) {
        Assert-Rollback (Test-Path -LiteralPath (Join-Path $oldBackup 'RYZOM_SERVER_UPDATE.json')) 'Alter Versionsmarker fehlt.'
    }

    Write-Host ""
    Write-Host 'ROLLBACK - Ryzom Core4 Server' -ForegroundColor Cyan
    Write-Host "Aktuelle Version: $($current.commit)"
    Write-Host "Gesichert in:     $oldBackup"
    Write-Host "Ziel:             $target"
    Write-Host 'Nur Server-EXEs und DLLs. Kein Datenbank- oder Config-Rollback.'
    $accept = Read-Host 'Letztes Serverupdate zuruecknehmen? JA eingeben'
    Assert-Rollback ($accept -ceq 'JA') 'Abgebrochen. Keine Dateien wurden veraendert.'

    # Keep a complete safety copy of the just-tested version as well.
    $safety = Join-Path $backupBase ('rollback-safety-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $current.commit.Substring(0, 8))
    Assert-Rollback (-not (Test-Path -LiteralPath $safety)) 'Sicherungsordner existiert bereits.'
    New-Item -ItemType Directory -Path $safety -Force | Out-Null
    foreach ($file in $installed) {
        $name = [string]$file
        Copy-Item -LiteralPath (Join-Path $target $name) -Destination (Join-Path $safety $name) -ErrorAction Stop
    }
    Copy-Item -LiteralPath $marker -Destination (Join-Path $safety 'RYZOM_SERVER_UPDATE.json') -ErrorAction Stop

    foreach ($file in $installed) {
        $name = [string]$file
        $destination = Join-Path $target $name
        $changed += $name
        if ($previous.ContainsKey($name)) {
            Copy-Item -LiteralPath (Join-Path $oldBackup $name) -Destination $destination -Force -ErrorAction Stop
        } else {
            Remove-Item -LiteralPath $destination -Force -ErrorAction Stop
        }
    }
    $markerTouched = $true
    if ($meta.previousMarker) {
        Copy-Item -LiteralPath (Join-Path $oldBackup 'RYZOM_SERVER_UPDATE.json') -Destination $marker -Force -ErrorAction Stop
    } else {
        Remove-Item -LiteralPath $marker -Force -ErrorAction Stop
    }

    Write-Host ""
    Write-Host 'ROLLBACK ERFOLGREICH' -ForegroundColor Green
    Write-Host "Letzte Version zusaetzlich gesichert in: $safety"
    Write-Host 'Server wieder starten und pruefen. Datenbank-/Config-Kompatibilitaet separat beachten.'
    exit 0
}
catch {
    Write-Host ""
    Write-Host "ROLLBACK ABGEBROCHEN: $($_.Exception.Message)" -ForegroundColor Red
    if ($safety -and $changed.Count -gt 0) {
        Write-Warning 'Wiederherstellung des vor dem Rollback installierten Zustands...'
        foreach ($name in $changed) {
            try {
                Copy-Item -LiteralPath (Join-Path $safety $name) -Destination (Join-Path $target $name) -Force -ErrorAction Stop
            } catch {
                Write-Warning ("Nicht wiederhergestellt: " + $name)
            }
        }
        try {
            if ($markerTouched) {
                Copy-Item -LiteralPath (Join-Path $safety 'RYZOM_SERVER_UPDATE.json') -Destination $marker -Force -ErrorAction Stop
            }
        } catch { Write-Warning 'Versionsmarker konnte nicht wiederhergestellt werden.' }
    }
    exit 1
}
