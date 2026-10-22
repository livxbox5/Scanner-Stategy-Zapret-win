# === FILE SCANNER (FileScanner.ps1) — winws2 ===
#  Поиск .txt (hostlist), .bin (blob-файлы) и .lua (zapret-lib / antidpi)
#  в указанной папке.
#
#  Поиск:
#    # === FIND-ALLFILES ===    найти .txt / .bin / .lua
#    # === SHOW-TXTCONTENT ===  показать содержимое .txt-файла
# ===============================================================

# === SHOW-TXTCONTENT ===
#  Показывает содержимое .txt-файла (первые N строк).
#  Вызывается из Find-AllFiles при -ShowContent.
function Show-TxtContent {
    param(
        [string]$FilePath,
        [int]$MaxLines = 50
    )

    if (-not $FilePath -or -not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        Write-Host ("  [!] Файл не найден: {0}" -f $FilePath) -ForegroundColor Yellow
        return
    }

    $info = Get-Item -LiteralPath $FilePath
    Write-Host ""
    Write-Host ("  ─── {0}  ({1} B) ───" -f $info.Name, $info.Length) -ForegroundColor Cyan

    try {
        $lines = @(Get-Content -LiteralPath $FilePath -ErrorAction Stop)
    } catch {
        Write-Host ("  [!] Ошибка чтения: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return
    }

    if ($lines.Count -eq 0) {
        Write-Host "  <пусто>" -ForegroundColor DarkGray
        return
    }

    $show = [Math]::Min($MaxLines, $lines.Count)
    for ($i = 0; $i -lt $show; $i++) {
        $l = $lines[$i]
        $col = if ($l -match '^\s*#') { "DarkGray" }
               elseif ($l -match '^\s*$') { "Black" }
               else { "White" }
        Write-Host ("  {0,4}: {1}" -f ($i + 1), $l) -ForegroundColor $col
    }

    if ($lines.Count -gt $show) {
        Write-Host ("  ... ещё {0} строк" -f ($lines.Count - $show)) -ForegroundColor DarkGray
    }
}

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