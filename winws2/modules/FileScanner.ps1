# === FILE SCANNER (FileScanner.ps1) — winws2 ===
#  Поиск .txt (hostlist), .bin (blob-файлы) и .lua (zapret-lib / antidpi)
#  в указанной папке.
#
#  Поиск:
#    # === FIND-ALLFILES ===    найти .txt / .bin / .lua
#    # === SHOW-TXTCONTENT ===  показать содержимое .txt-файла
# ===============================================================

# === FIND-ALLFILES === 
function Find-AllFiles {
    param(
        [string]$RootPath,
        [switch]$OnlyTxt,
        [switch]$OnlyBin,
        [switch]$OnlyLua,
        [switch]$ShowContent
    )

    if (-not $RootPath) { $RootPath = Get-Winws2Dir }

    if (-not $RootPath -or -not (Test-Path $RootPath)) {
        Write-Log "Путь для поиска не задан или не существует" "ERR"
        return
    }

    Write-Log "Сканирую: $RootPath"

    $files = @(
        Get-ChildItem -Path $RootPath -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $ext = $_.Extension.ToLower()
                if ($OnlyTxt) { return $ext -eq '.txt' }
                if ($OnlyBin) { return $ext -eq '.bin' }
                if ($OnlyLua) { return $ext -eq '.lua' }
                return ($ext -eq '.txt' -or $ext -eq '.bin' -or $ext -eq '.lua')
            } | Sort-Object FullName
    )

    if ($files.Count -eq 0) {
        Write-Host "Файлы не найдены." -ForegroundColor Yellow
        return
    }

    $txtCount = @($files | Where-Object { $_.Extension.ToLower() -eq '.txt' }).Count
    $binCount = @($files | Where-Object { $_.Extension.ToLower() -eq '.bin' }).Count
    $luaCount = @($files | Where-Object { $_.Extension.ToLower() -eq '.lua' }).Count

    Write-Host ""
    Write-Host ("═" * 80) -ForegroundColor Cyan
    Write-Host ("  Найдено файлов: {0}   (TXT: {1}   BIN: {2}   LUA: {3})" -f $files.Count, $txtCount, $binCount, $luaCount) -ForegroundColor Cyan
    Write-Host ("═" * 80) -ForegroundColor Cyan

    $i = 0
    foreach ($f in $files) {
        $i++
        $ext = $f.Extension.ToLower()
        $type = switch ($ext) {
            '.txt' { "TXT" }
            '.bin' { "BIN" }
            '.lua' { "LUA" }
            default { "???" }
        }
        $color = switch ($type) {
            "TXT" { "White" }
            "BIN" { "Gray" }
            "LUA" { "Cyan" }
            default { "DarkGray" }
        }
        $size = "{0,10:N0}" -f $f.Length
        Write-Host ("  [{0,4}] {1}  {2} B  {3}" -f $i, $type, $size, $f.FullName) -ForegroundColor $color
    }

    Write-Host ("═" * 80) -ForegroundColor Cyan

    if ($ShowContent) {
        $txts = @($files | Where-Object { $_.Extension.ToLower() -eq '.txt' })
        foreach ($t in $txts) {
            Show-TxtContent -FilePath $t.FullName
        }
    }

    return $files
}