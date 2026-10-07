# ===============================================================
# === SETTINGS (Settings.ps1) — winws2 ===
# ===============================================================
#  Установка путей: winws2.exe, Lua-скрипты, .txt, .bin.
#  Если для Lua передан каталог — автопоиск файла внутри.
# ===============================================================

# === SET-WINWS2PATH ===
function Set-Winws2Path {
    $path = Read-Host "Путь к winws2.exe / папка с ним"
    $path = $path.Trim('"').Trim("'")

    if (-not (Test-Path $path)) {
        Write-Log "Не найдено: $path" "ERR"
        return
    }

    $item = Get-Item $path
    if ($item.PSIsContainer) {
        $exe = Join-Path $item.FullName 'winws2.exe'
        if (-not (Test-Path $exe)) {
            Write-Log "В папке нет winws2.exe: $($item.FullName)" "ERR"
            return
        }
        $Global:ZapretState.Winws2Path = $exe
    } else {
        $Global:ZapretState.Winws2Path = $item.FullName
    }

    Save-Settings
    Write-Log ("Winws2Path: {0}" -f $Global:ZapretState.Winws2Path)
}

# === SET-LUALIBPATH ===
function Set-LuaLibPath {
    $path = (Read-Host "Путь к zapret-lib.lua (или папке lua\)").Trim('"').Trim("'")
    $resolved = Resolve-Winws2LuaPath -Path $path -TargetName 'zapret-lib.lua'
    if (-not $resolved) {
        Write-Log "Не найден zapret-lib.lua по пути: $path" "ERR"
        return
    }
    $Global:ZapretState.LuaLibPath = $resolved
    Save-Settings
    Write-Log "LuaLibPath: $($Global:ZapretState.LuaLibPath)"
}

# === SET-LUAANTIDPIPATH ===
function Set-LuaAntiDpiPath {
    $path = (Read-Host "Путь к zapret-antidpi.lua (или папке lua\)").Trim('"').Trim("'")
    $resolved = Resolve-Winws2LuaPath -Path $path -TargetName 'zapret-antidpi.lua'
    if (-not $resolved) {
        Write-Log "Не найден zapret-antidpi.lua по пути: $path" "ERR"
        return
    }
    $Global:ZapretState.LuaAntiDpiPath = $resolved
    Save-Settings
    Write-Log "LuaAntiDpiPath: $($Global:ZapretState.LuaAntiDpiPath)"
}

# === SET-TXTPATH ===
# === SET-TXTPATH ===
# Принимает ЛИБО папку с .txt, ЛИБО конкретный .txt-файл.
function Set-TxtPath {
    Write-Host "  Можно указать:" -ForegroundColor DarkGray
    Write-Host "    - ПАПКУ  → будут прочитаны ВСЕ .txt внутри" -ForegroundColor DarkGray
    Write-Host "    - ФАЙЛ   → будет прочитан ТОЛЬКО этот .txt" -ForegroundColor DarkGray
    $path = (Read-Host "Путь").Trim('"').Trim("'")

    if (-not (Test-Path $path)) {
        Write-Log "Не найдено: $path" "ERR"
        return
    }

    $item = Get-Item $path
    if ($item.PSIsContainer) {
        # Папка
        $Global:ZapretState.TxtPath = $item.FullName
        $cnt = @(Get-ChildItem $item.FullName -Filter '*.txt' -File -ErrorAction SilentlyContinue).Count
        Save-Settings
        Write-Log "TxtPath (папка): $($item.FullName) — .txt: $cnt"
    }
    elseif ($item.Extension.ToLower() -eq '.txt') {
        # Конкретный файл
        $Global:ZapretState.TxtPath = $item.FullName
        Save-Settings
        Write-Log "TxtPath (файл): $($item.FullName)"
    }
    else {
        Write-Log "Это не папка и не .txt-файл: $path" "ERR"
    }
}

# === SET-BINPATH ===
function Set-BinPath {
    $path = (Read-Host "Папка с .bin-файлами (blob)").Trim('"').Trim("'")
    if (Test-Path $path) {
        $Global:ZapretState.BinPath = (Get-Item $path).FullName
        Save-Settings
        Write-Log "BinPath: $($Global:ZapretState.BinPath)"
    } else {
        Write-Log "Папка не найдена: $path" "ERR"
    }
}