# ===============================================================
# === CONVERT (Convert.ps1) ===
# ===============================================================
#  Конвертер resultats\*.txt → strategies.bat.
#  Только zapret1 (winws.exe).
#
#  Что делает:
#    1. Находит папку resultats\ и свежий resultat.txt/pretest.txt.
#    2. Подставляет %LISTS% / %BIN% / %TCPPort% / %UDPPort%.
#    3. Пишет strategies.bat со строкой:
#         start "zapret" /min "%BIN%winws.exe" --dpi-desync=...
# ===============================================================

# ─── ПОРТЫ ДЛЯ .bat ─────────────────────────────────────────
$TCPPort = "80,443,2053,2083,2087,2096,8443"
$UDPPort = "443,19294-19344,50000-50100"

# ─── Авто-поиск папки resultats\ ────────────────────────────
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$searchPaths = @(
    (Join-Path $scriptDir 'resultats'),
    (Join-Path $scriptDir '..\resultats'),
    (Join-Path $scriptDir '..\..\resultats'),
    (Join-Path (Get-Location) 'resultats'),
    (Join-Path (Get-Location) '..\resultats')
)

$ResultDir = $null
foreach ($p in $searchPaths) {
    $full = [System.IO.Path]::GetFullPath($p)
    if (Test-Path $full) { $ResultDir = $full; break }
}

Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Cyan
Write-Host "         ZAPRET -- CONVERTER  (resultats\*.txt -> .bat)" -ForegroundColor Cyan
Write-Host "  ==============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $ResultDir) {
    Write-Host "  [!] Не найдена папка resultats\." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Искал в:" -ForegroundColor Yellow
    foreach ($p in $searchPaths) {
        Write-Host ("    - {0}" -f [System.IO.Path]::GetFullPath($p)) -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  Сначала запусти ZapretManager -> пункт 8 (авто-тест)." -ForegroundColor Yellow
    Read-Host "  Enter..."
    exit 1
}

$usRoot = Split-Path $ResultDir -Parent
$OutBat = Join-Path $usRoot 'strategies.bat'

Write-Host ("  Папка:  {0}" -f $ResultDir) -ForegroundColor DarkCyan
Write-Host ("  Выход:  {0}" -f $OutBat)     -ForegroundColor DarkCyan
Write-Host ""

# ─── ПАРСЕР ФАЙЛОВ РЕЗУЛЬТАТОВ ───────────────────────────────
function Parse-ResultFile {
    param([string]$Path)

    $raw   = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $lines = $raw -split "`r?`n"
    $list  = New-Object System.Collections.Generic.List[object]

    # Формат 1: resultat.txt — "# #N [x/y] method"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i].Trim()
        if ($l -match '^#\s*#(\d+)\s*\[(\d+)/(\d+)\]\s*(.+)$') {
            $rank   = [int]$Matches[1]
            $score  = [int]$Matches[2]
            $total  = [int]$Matches[3]
            $method = $Matches[4].Trim()

            $cmd = ""
            for ($j = $i + 1; $j -lt $lines.Count -and $j -lt ($i + 12); $j++) {
                $c = $lines[$j].Trim()
                if ($c -eq '' -or $c -eq '--new' -or $c.StartsWith('#') -or $c.StartsWith('::')) { continue }
                $cmd = $c
                $i = $j
                break
            }
            if ($cmd) {
                $list.Add([pscustomobject]@{
                    Rank    = $rank
                    Score   = $score
                    Total   = $total
                    Percent = if ($total -gt 0) { [math]::Round($score / $total * 100, 1) } else { 0 }
                    Method  = $method
                    Cmd     = $cmd
                }) | Out-Null
            }
        }
    }

    # Формат 2: pretest.txt
    if ($list.Count -eq 0) {
        $i = 0
        $curScore = 0; $curTotal = 0; $curMethod = ""

        while ($i -lt $lines.Count) {
            $l = $lines[$i].Trim()

            if ($l -match '^#\s*.*?Score:\s*(\d+)/(\d+)\s*$') {
                $curScore  = [int]$Matches[1]
                $curTotal  = [int]$Matches[2]
                $curMethod = ""
                $i++
                continue
            }

            if ($l -match '^#\s*.*?\[(\d+)/(\d+)\]\s*(.*)$') {
                $curScore  = [int]$Matches[1]
                $curTotal  = [int]$Matches[2]
                $curMethod = $Matches[3].Trim()
                $i++
                continue
            }

            if ($l -eq '--new') {
                for ($j = $i + 1; $j -lt $lines.Count -and $j -lt ($i + 6); $j++) {
                    $c = $lines[$j].Trim()
                    if ($c -eq '' -or $c.StartsWith('#') -or $c.StartsWith('::') -or $c -eq '--new') { continue }
                    $m = if ($curMethod) { $curMethod } else { $c.Substring(0, [Math]::Min(80, $c.Length)) }
                    $list.Add([pscustomobject]@{
                        Rank    = $list.Count + 1
                        Score   = $curScore
                        Total   = $curTotal
                        Percent = if ($curTotal -gt 0) { [math]::Round($curScore / $curTotal * 100, 1) } else { 0 }
                        Method  = $m
                        Cmd     = $c
                    }) | Out-Null
                    $curScore = 0; $curTotal = 0; $curMethod = ""
                    $i = $j
                    break
                }
            }
            $i++
        }
    }

    $format = if ($list.Count -eq 0) { "пусто" }
              elseif ($list[0].Total -gt 0) { "resultat" }
              else { "pretest" }

    return [pscustomobject]@{
        File          = (Split-Path $Path -Leaf)
        Path          = $Path
        LastWriteTime = (Get-Item $Path).LastWriteTime
        Count         = $list.Count
        Format        = $format
        Strategies    = $list.ToArray()
    }
}

$files = @(Get-ChildItem -Path $ResultDir -Filter '*.txt' -File -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending)

if ($files.Count -eq 0) {
    Write-Host "  [!] В папке resultats\ нет .txt файлов." -ForegroundColor Red
    Read-Host "  Enter..."
    exit 1
}

$parsed = @()
foreach ($f in $files) {
    $parsed += Parse-ResultFile -Path $f.FullName
}

Write-Host "  Файлы в resultats\:" -ForegroundColor DarkCyan
Write-Host ""
Write-Host ("    {0,-4} {1,-10} {2,-17} {3,-10} {4,-9} {5}" -f "#", "Размер", "Дата", "Стратегий", "Формат", "Имя") -ForegroundColor DarkGray
Write-Host ("    " + ("-" * 78)) -ForegroundColor DarkGray

$i = 0
foreach ($p in $parsed) {
    $i++
    $src = Get-Item $p.Path
    $size = "{0,8:N0}" -f $src.Length
    $date = $src.LastWriteTime.ToString('yyyy-MM-dd HH:mm')

    $color = if ($p.Format -eq "resultat" -and $p.Count -gt 0) { "Green" }
             elseif ($p.Format -eq "pretest" -and $p.Count -gt 0) { "Yellow" }
             else { "DarkGray" }

    Write-Host ("    [{0}] {1}  {2}  {3,-10} {4,-9} {5}" -f `
        $i, $size, $date, $p.Count, $p.Format, $p.File) -ForegroundColor $color
}

Write-Host ""
Write-Host "  Легенда:  resultat — готовые рабочие стратегии (полный прогон)" -ForegroundColor DarkGray
Write-Host "            pretest  — прошли только пре-тест (черновик)" -ForegroundColor DarkGray
Write-Host ""

$bestResultat = $parsed | Where-Object { $_.Format -eq 'resultat' -and $_.Count -gt 0 } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

$bestPretest  = $parsed | Where-Object { $_.Format -eq 'pretest' -and $_.Count -gt 0 } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

if ($bestResultat) {
    $autoPick = $bestResultat
    Write-Host ("  Авто-выбор: [{0}] — свежий resultat с {1} стратегиями" -f `
        ([array]::IndexOf($parsed, $bestResultat) + 1), $bestResultat.Count) -ForegroundColor Green
}
elseif ($bestPretest) {
    $autoPick = $bestPretest
    Write-Host ("  Авто-выбор: [{0}] — только pretest ({1} стратегий, полного прогона не было)" -f `
        ([array]::IndexOf($parsed, $bestPretest) + 1), $bestPretest.Count) -ForegroundColor Yellow
}
else {
    Write-Host "  [!] Ни в одном файле не найдено стратегий." -ForegroundColor Red
    Read-Host "  Enter..."
    exit 1
}

Write-Host ""
Write-Host "  Выбрать другой файл? (Enter — оставить, номер — сменить, 0 — отмена): " -NoNewline -ForegroundColor Cyan
$sel = Read-Host

if ($sel -eq '0') {
    Write-Host "  Отмена." -ForegroundColor Yellow
    exit 0
}
elseif (-not [string]::IsNullOrWhiteSpace($sel)) {
    $n = 0
    if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le $parsed.Count) {
        $autoPick = $parsed[$n - 1]
        if ($autoPick.Count -eq 0) {
            Write-Host "  [!] В выбранном файле нет стратегий." -ForegroundColor Red
            Read-Host "  Enter..."
            exit 1
        }
    } else {
        Write-Host "  [!] Неверный номер — оставляю авто-выбор." -ForegroundColor Yellow
    }
}

$strategies = @($autoPick.Strategies)

# ─── читаем settings.yml ────────────────────────────────────
$ConfigFile = Join-Path $usRoot 'config\settings.yml'
$listsPath  = ""
$binPath    = ""
$winwsPath  = ""

if (Test-Path $ConfigFile) {
    $raw = [System.IO.File]::ReadAllText($ConfigFile, [System.Text.Encoding]::UTF8)
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -match '^\s*TxtPath:\s*"?([^"\r\n]+?)"?\s*$') {
            $listsPath = $Matches[1].Trim()
        }
        if ($line -match '^\s*BinPath:\s*"?([^"\r\n]+?)"?\s*$') {
            $binPath = $Matches[1].Trim()
        }
        if ($line -match '^\s*WinwsPath:\s*"?([^"\r\n]+?)"?\s*$') {
            $winwsPath = $Matches[1].Trim()
        }
    }
}

if (-not $listsPath) { $listsPath = Join-Path $usRoot 'lists' }
if (-not $binPath)   { $binPath   = Join-Path $usRoot 'bin' }

$activeExe = $winwsPath
$exeName   = 'winws.exe'

$listsPath = ($listsPath -replace '\\','/').TrimEnd('/')
$binPath   = ($binPath   -replace '\\','/').TrimEnd('/')

Write-Host ("  LISTS:    {0}" -f $listsPath) -ForegroundColor DarkGray
Write-Host ("  BIN:      {0}" -f $binPath)   -ForegroundColor DarkGray
Write-Host "  Движок:   zapret1 (winws.exe)" -ForegroundColor DarkCyan
Write-Host ("  Активный: {0}" -f $(if ($activeExe) { $activeExe } else { "<не найден>" })) -ForegroundColor DarkGray
Write-Host ("  TCPPort:  {0}" -f $TCPPort)   -ForegroundColor DarkGray
Write-Host ("  UDPPort:  {0}" -f $UDPPort)   -ForegroundColor DarkGray
Write-Host ""

# ─── ЗАМЕНА ПУТЕЙ И ПОРТОВ + ЧИСТКА ЧУЖИХ VAR ────────────────
function Convert-Paths {
    param([string]$S)

    if (-not $S) { return $S }

    $known = @('%LISTS%','%BIN%','%TCPPort%','%UDPPort%')

    # 1. Реальные пути → %LISTS% (для hostlist)
    $escLists = [regex]::Escape($listsPath)
    $S = $S -replace ('(--hostlist[^=]*=")' + $escLists + '/'), '$1%LISTS%'
    $S = $S -replace ('(--hostlist-exclude=")' + $escLists + '/'), '$1%LISTS%'

    # 1b. Fake-файлы (.bin) — оставляем как относительные имена,
    #     winws.exe ищет их в рабочей директории (bin\)
    $escBin = [regex]::Escape($binPath)
    $S = $S -replace ('(--dpi-desync-fake-\w+=")' + $escBin + '/'), '$1'

    # 2. Порты
    $S = $S -replace '--wf-tcp=[\d,\-]+', '--wf-tcp=%TCPPort%'
    $S = $S -replace '--wf-udp=[\d,\-]+', '--wf-udp=%UDPPort%'

    # 3. Чужие %VAR%
    $badVars = @(
        [regex]::Matches($S, '%[A-Za-z_][A-Za-z0-9_]*%') |
        ForEach-Object { $_.Value } |
        Where-Object { $known -notcontains $_ } |
        Select-Object -Unique
    )
    foreach ($v in $badVars) {
        Write-Host ("    [!] В команде чужой VAR, удаляю: {0}" -f $v) -ForegroundColor Yellow
        $S = $S -replace [regex]::Escape($v), ''
    }

    $S = $S -replace '\s+', ' '
    return $S.Trim()
}

# ─── Ключевой параметр: --dpi-desync ───
$keyParam = '--dpi-desync'

$strategies = @($strategies | ForEach-Object {
    $cmd2 = Convert-Paths $_.Cmd

    if (-not $cmd2 -or $cmd2 -notmatch [regex]::Escape($keyParam)) {
        Write-Host ("    [!] Пропускаю стратегию #{0} — после чистки нет {1}" -f $_.Rank, $keyParam) -ForegroundColor DarkRed
        return
    }

    [pscustomobject]@{
        Rank    = $_.Rank
        Score   = $_.Score
        Total   = $_.Total
        Percent = $_.Percent
        Method  = $_.Method
        Cmd     = $cmd2
    }
})

if ($strategies.Count -eq 0) {
    Write-Host "  [!] После обработки не осталось стратегий." -ForegroundColor Red
    Read-Host "  Enter..."
    exit 1
}

Write-Host ""
Write-Host ("  Источник: {0}" -f $autoPick.File) -ForegroundColor Gray
Write-Host ("  Найдено:  {0} стратегий" -f $strategies.Count) -ForegroundColor Green
Write-Host ""
Write-Host "  Пример первой стратегии (после замены):" -ForegroundColor DarkGray
$first = $strategies[0].Cmd
if ($first.Length -gt 120) { $first = $first.Substring(0, 117) + "..." }
Write-Host ("    {0}" -f $first) -ForegroundColor DarkGray

# ─── ГЕНЕРАЦИЯ .bat ──────────────────────────────────────────
$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine('@echo off')
[void]$sb.AppendLine('chcp 65001 > nul')
[void]$sb.AppendLine(':: 65001 - UTF-8')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('cd /d "%~dp0"')
[void]$sb.AppendLine('')
[void]$sb.AppendLine(':: Сервисные вызовы (если есть service.bat)')
[void]$sb.AppendLine('if exist service.bat (')
[void]$sb.AppendLine('    call service.bat status_zapret')
[void]$sb.AppendLine('    call service.bat check_updates')
[void]$sb.AppendLine('    call service.bat load_game_filter')
[void]$sb.AppendLine('    call service.bat load_user_lists')
[void]$sb.AppendLine(')')
[void]$sb.AppendLine('echo:')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('set "BIN=%~dp0bin\"')
[void]$sb.AppendLine('set "LISTS=%~dp0lists\"')
[void]$sb.AppendLine(('set "TCPPort={0}"' -f $TCPPort))
[void]$sb.AppendLine(('set "UDPPort={0}"' -f $UDPPort))
[void]$sb.AppendLine('cd /d %BIN%')
[void]$sb.AppendLine('')
[void]$sb.AppendLine(':: ===============================================================')
[void]$sb.AppendLine("::  АВТО-СГЕНЕРИРОВАНО $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("::  Источник: $($autoPick.File)")
[void]$sb.AppendLine("::  Движок:  zapret1 (winws.exe)")
[void]$sb.AppendLine("::  Всего стратегий: $($strategies.Count)")
[void]$sb.AppendLine(':: ---------------------------------------------------------------')
[void]$sb.AppendLine('::  КАК ПОЛЬЗОВАТЬСЯ:')
[void]$sb.AppendLine('::    1. Выбери нужную стратегию из блока ниже')
[void]$sb.AppendLine('::    2. Сними ":: " со строки start ... и запусти снова')
[void]$sb.AppendLine(':: ===============================================================')
[void]$sb.AppendLine('')

foreach ($s in $strategies) {
    $tag = if ($s.Total -gt 0 -and $s.Score -eq $s.Total) { 'IDEAL' }
           elseif ($s.Total -gt 0 -and $s.Percent -ge 75) { 'GOOD' }
           elseif ($s.Total -gt 0) { 'WEAK' }
           else { 'UNKNOWN' }

    $fullCmd = ('start "zapret" /min "%BIN%{0}" ' -f $exeName) + $s.Cmd

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(':: =======')
    if ($s.Total -gt 0) {
        [void]$sb.AppendLine((":: Стратегия {0}   [{1}/{2}]  {3}%  [{4}]" -f $s.Rank, $s.Score, $s.Total, $s.Percent, $tag))
    } else {
        [void]$sb.AppendLine((":: Стратегия {0}" -f $s.Rank))
    }
    [void]$sb.AppendLine(':: =======')
    [void]$sb.AppendLine((':: ' + $fullCmd))
}

[void]$sb.AppendLine(':: ===============================================================')
[void]$sb.AppendLine('echo:')
[void]$sb.AppendLine('echo   Ни одна стратегия не активна.')
[void]$sb.AppendLine('echo   Открой strategies.bat, найди нужную секцию,')
[void]$sb.AppendLine('echo   сними ":: " со строки start ... и запусти снова.')
[void]$sb.AppendLine('echo:')
[void]$sb.AppendLine('pause')

$enc = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutBat, $sb.ToString(), $enc)

# ─── ТОП-10 ──────────────────────────────────────────────────
Write-Host "  --- ТОП-10 ---" -ForegroundColor Cyan
$show = [Math]::Min(10, $strategies.Count)
for ($i = 0; $i -lt $show; $i++) {
    $p = $strategies[$i]
    $color = if ($p.Total -gt 0 -and $p.Score -eq $p.Total) { 'Green' }
             elseif ($p.Total -gt 0 -and $p.Percent -ge 75) { 'Yellow' }
             else { 'White' }
    $m = if ($p.Method.Length -gt 70) { $p.Method.Substring(0, 67) + '...' } else { $p.Method }
    $scoreStr = if ($p.Total -gt 0) { "[{0,2}/{1}]  {2,5}%" -f $p.Score, $p.Total, $p.Percent } else { "        " }
    Write-Host ("    [{0,2}]  {1}  {2}" -f $p.Rank, $scoreStr, $m) -ForegroundColor $color
}

Write-Host ""
Write-Host "  --- Готово ---" -ForegroundColor Cyan
Write-Host ("    Файл:    {0}" -f $OutBat) -ForegroundColor Green
Write-Host ("    Строк:   {0} стратегий" -f $strategies.Count) -ForegroundColor Green
Write-Host "    Движок:  zapret1 (winws.exe)" -ForegroundColor Green
Write-Host ""

Write-Host "  Открыть папку с файлом? (Y/N): " -NoNewline -ForegroundColor Cyan
$ans = Read-Host
if ($ans -match '^[YyДд]') {
    Start-Process explorer.exe -ArgumentList ("/select,`"$OutBat`"")
}