# ===============================================================
# === LAUNCHER (Launcher.ps1) ===
# ===============================================================
#  Запуск и остановка winws.exe (zapret1).
# ===============================================================

# === START-ZAPRET ===
function Start-Zapret {
    param([string]$StrategyLine)

    if (-not (Test-Admin)) {
        Write-Log "winws требует прав администратора. Перезапустите PowerShell от имени администратора." "ERR"
        return
    }

    $winws = $Global:ZapretState.WinwsPath
    if (-not $winws -or -not (Test-Path $winws)) {
        Write-Log "winws.exe не найден. Укажите путь в настройках (пункт 1)." "ERR"
        return
    }

    if ([string]::IsNullOrWhiteSpace($StrategyLine)) {
        $StrategyLine = Read-Host "Аргументы стратегии (строка)"
    }

    $winwsDir = Split-Path $winws -Parent

    try {
        Start-Process -FilePath $winws `
                      -ArgumentList $StrategyLine `
                      -WorkingDirectory $winwsDir `
                      -WindowStyle Minimized
        $Global:ZapretState.Running = $true
        Write-Log ("Запущен {0}" -f (Split-Path $winws -Leaf))
    } catch {
        Write-Log "Ошибка запуска: $_" "ERR"
    }
}

# === STOP-ZAPRET ===
function Stop-Zapret {
    $procName = Get-ProcName
    $procs = Get-Process $procName -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force
        Write-Log ("{0} остановлен ({1} проц.)" -f $procName, $procs.Count)
    } else {
        Write-Log ("{0} не запущен" -f $procName)
    }
    $Global:ZapretState.Running = $false
}

# === SHOW-ZAPRETSTATUS ===
function Show-ZapretStatus {
    $procName = Get-ProcName
    $procs = Get-Process $procName -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host ("  Статус: РАБОТАЕТ ({0}, {1} проц.)" -f $procName, $procs.Count) -ForegroundColor Green
    } else {
        Write-Host ("  Статус: ОСТАНОВЛЕН ({0})" -f $procName) -ForegroundColor DarkGray
    }
}