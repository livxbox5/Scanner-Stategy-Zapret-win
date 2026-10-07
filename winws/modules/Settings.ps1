# ===============================================================
# === SETTINGS (Settings.ps1) ===
# ===============================================================
#  Установка путей: winws.exe, .txt, .bin.
#
#  Поиск:
#    # === SET-WINWSPATH ===  путь к winws.exe (файл или папка)
#    # === SET-TXTPATH ===    папка с .txt (hostlist)
#    # === SET-BINPATH ===    папка с .bin (fake payloads)
# ===============================================================

# === SET-WINWSPATH ===
function Set-WinwsPath {
    $path = Read-Host "Путь к winws.exe / папка с ним"
    $path = $path.Trim('"').Trim("'")

    if (-not (Test-Path $path)) {
        Write-Log "Не найдено: $path" "ERR"
        return
    }

    $item = Get-Item $path
    if ($item.PSIsContainer) {
        $exe = Join-Path $item.FullName 'winws.exe'
        if (-not (Test-Path $exe)) {
            Write-Log "В папке нет winws.exe: $($item.FullName)" "ERR"
            return
        }
        $Global:ZapretState.WinwsPath = $exe
    } else {
        $Global:ZapretState.WinwsPath = $item.FullName
    }

    Save-Settings
    Write-Log ("WinwsPath: {0}" -f $Global:ZapretState.WinwsPath)
}

# === SET-TXTPATH ===
function Set-TxtPath {
    $path = (Read-Host "Папка с .txt-файлами (hostlist)").Trim('"').Trim("'")
    if (Test-Path $path) {
        $Global:ZapretState.TxtPath = (Get-Item $path).FullName
        Save-Settings
        Write-Log "TxtPath: $($Global:ZapretState.TxtPath)"
    } else {
        Write-Log "Папка не найдена: $path" "ERR"
    }
}

# === SET-BINPATH ===
function Set-BinPath {
    $path = (Read-Host "Папка с .bin-файлами (fake payloads)").Trim('"').Trim("'")
    if (Test-Path $path) {
        $Global:ZapretState.BinPath = (Get-Item $path).FullName
        Save-Settings
        Write-Log "BinPath: $($Global:ZapretState.BinPath)"
    } else {
        Write-Log "Папка не найдена: $path" "ERR"
    }
}