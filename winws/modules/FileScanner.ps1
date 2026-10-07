# ===============================================================
# === FILE SCANNER (FileScanner.ps1) ===
# ===============================================================
#  Поиск .txt (hostlist) и .bin (fake payloads) в указанной папке.
#
#  Поиск:
#    # === FIND-ALLFILES ===    найти .txt / .bin (флаги OnlyTxt/OnlyBin)
#    # === SHOW-TXTCONTENT ===  показать содержимое .txt-файла
# ===============================================================

# === FIND-ALLFILES ===
function Find-AllFiles {
    param(
        [string]$RootPath,
        [switch]$OnlyTxt,
        [switch]$OnlyBin,
        [switch]$ShowContent
    )

    if (-not $RootPath) { $RootPath = Get-WinwsDir }

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
                return ($ext -eq '.txt' -or $ext -eq '.bin')
            } | Sort-Object FullName
    )

    if ($files.Count -eq 0) {
        Write-Host "Файлы не найдены." -ForegroundColor Yellow
        return
    }

    $txtCount = @($files | Where-Object { $_.Extension -eq '.txt' }).Count
    $binCount = @($files | Where-Object { $_.Extension -eq '.bin' }).Count

    Write-Host ""
    Write-Host ("═" * 80) -ForegroundColor Cyan
    Write-Host ("  Найдено файлов: {0}   (TXT: {1}   BIN: {2})" -f $files.Count, $txtCount, $binCount) -ForegroundColor Cyan
    Write-Host ("═" * 80) -ForegroundColor Cyan

    $i = 0
    foreach ($f in $files) {
        $i++
        $type  = if ($f.Extension -eq '.txt') { "TXT" } else { "BIN" }
        $color = if ($type -eq "TXT") { "White" } else { "Gray" }
        $size  = "{0,10:N0}" -f $f.Length
        Write-Host ("  [{0,4}] {1}  {2} B  {3}" -f $i, $type, $size, $f.FullName) -ForegroundColor $color
    }

    Write-Host ("═" * 80) -ForegroundColor Cyan

    if ($ShowContent) {
        $txts = @($files | Where-Object { $_.Extension -eq '.txt' })
        foreach ($t in $txts) {
            Show-TxtContent -FilePath $t.FullName
        }
    }

    return $files
}

# === SHOW-TXTCONTENT ===
function Show-TxtContent {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { return }

    $lines = @(Get-Content $FilePath -ErrorAction SilentlyContinue)
    Write-Host ""
    Write-Host ("─" * 80) -ForegroundColor Yellow
    Write-Host ("  {0}  ({1} строк)" -f $FilePath, $lines.Count) -ForegroundColor Yellow
    Write-Host ("─" * 80) -ForegroundColor Yellow

    $n = 0
    foreach ($line in $lines) {
        $n++
        Write-Host ("  {0,4}│ {1}" -f $n, $line)
    }
    Write-Host ("─" * 80) -ForegroundColor Yellow
}