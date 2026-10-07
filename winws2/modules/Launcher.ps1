# ===============================================================
# === LAUNCHER (Launcher.ps1) — winws2 ===
# ===============================================================
#  Запуск и остановка winws2.exe (zapret2 / Lua).
# ===============================================================

function Start-Zapret {
    param([string]$StrategyLine)

    if (-not (Test-Admin)) {
        Write-Log "winws2 требует прав администратора. Перезапустите PowerShell от имени администратора." "ERR"
        return
    }

    $winws = $Global:ZapretState.Winws2Path
    if (-not $winws -or -not (Test-Path $winws)) {
        Write-Log "winws2.exe не найден. Укажите путь в настройках (пункт 1)." "ERR"
        return
    }

    if ([string]::IsNullOrWhiteSpace($StrategyLine)) {
        $StrategyLine = Read-Host "Аргументы стратегии (строка)"
    }

    $winwsDir = Split-Path $winws -Parent

    # Сначала гасим возможные старые процессы
    Get-Process (Get-ProcName) -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 300

    try {
        $proc = Start-Process -FilePath $winws `
                              -ArgumentList $StrategyLine `
                              -WorkingDirectory $winwsDir `
                              -PassThru -WindowStyle Minimized

        Start-Sleep -Milliseconds 700

        if ($proc.HasExited) {
            Write-Log ("winws2 упал сразу, код {0}. Проверьте строку стратегии." -f $proc.ExitCode) "ERR"
            Write-Host ""
            Write-Host "  Строка стратегии:" -ForegroundColor DarkYellow
            Write-Host ("  {0}" -f $StrategyLine) -ForegroundColor Gray
            $Global:ZapretState.Running = $false
            return
        }

        $Global:ZapretState.Running = $true
        Write-Log ("Запущен {0} (PID {1})" -f (Split-Path $winws -Leaf), $proc.Id)
    } catch {
        Write-Log "Ошибка запуска: $_" "ERR"
        $Global:ZapretState.Running = $false
    }
}

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

function Show-ZapretStatus {
    $procName = Get-ProcName
    $procs = Get-Process $procName -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host ("  Статус: РАБОТАЕТ ({0}, {1} проц.)" -f $procName, $procs.Count) -ForegroundColor Green
    } else {
        Write-Host ("  Статус: ОСТАНОВЛЕН ({0})" -f $procName) -ForegroundColor DarkGray
    }
}