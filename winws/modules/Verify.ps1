# Verify.ps1 — проверка и промоут стратегий из pretest.txt в resultat.txt
# ═════════════════════════════════════════════════════════════
#  ПАРСИНГ
# ═════════════════════════════════════════════════════════════

# ===============================================================
# === VERIFY (Verify.ps1) ===
# ===============================================================
#  Проверка pretest.txt и resultat.txt, промоут годных в resultat.txt.
#  Меню: пункты 25-26.
#
#  Поиск:
#    # === GET-STRATEGIESFROMFILE === парсер обоих форматов
#    # === SHOW-FILESTATS ===         статистика по файлу
#    # === SAVE-RESULTATFILE ===      записать resultat.txt
#    # === INVOKE-VERIFYSCAN ===      главная функция пункта 26
#    # === SHOW-RESULTSSTATS ===      пункт 25 (статистика)
# ===============================================================

function Get-StrategiesFromFile {
    param(
        [string]$Path,
        [string]$Kind = "auto"
    )

    if (-not (Test-Path $Path)) { return @() }

    $raw   = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $lines = $raw -split "`r?`n"
    $list  = New-Object System.Collections.Generic.List[object]

    # Формат resultat.txt: "# #N  [x/y]  --dpi-desync=..."
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

    # Формат pretest.txt: "--new" + команда
    # Регулярка ловит любой заголовок между # и [x/y]
    if ($list.Count -eq 0 -or $Kind -eq "pretest") {
        $i = 0
        $curScore  = 0
        $curTotal  = 0
        $curMethod = ""

        while ($i -lt $lines.Count) {
            $l = $lines[$i].Trim()

            # ─── НОВЫЙ формат: "# СТРАТЕГИЯ N  →  Score: X/Y" ───
            if ($l -match '^#\s*.*?Score:\s*(\d+)/(\d+)\s*$') {
                $curScore  = [int]$Matches[1]
                $curTotal  = [int]$Matches[2]
                $curMethod = ""     # в заголовке метода нет, возьмём из команды
                $i++
                continue
            }

            # ─── Старый формат: "# ПРЕ-ТЕСТ: [X/Y] method" ───
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

                    $curScore  = 0
                    $curTotal  = 0
                    $curMethod = ""

                    $i = $j
                    break
                }
            }
            $i++
        }
    }

    return $list.ToArray()
}

function Show-FileStats {
    param([string]$Path, [string]$Title, [string]$Color)

    Write-Host ""
    Write-Host ("  --- {0} ---" -f $Title) -ForegroundColor $Color

    if (-not (Test-Path $Path)) {
        Write-Host "  [!] Файл не найден" -ForegroundColor Yellow
        return @()
    }

    $info = Get-Item $Path
    $items = @(Get-StrategiesFromFile -Path $Path)

    Write-Host ("  Файл:      {0}" -f $info.Name) -ForegroundColor Gray
    Write-Host ("  Размер:    {0} B" -f $info.Length) -ForegroundColor Gray
    Write-Host ("  Дата:      {0}" -f $info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Gray
    Write-Host ("  Стратегий: {0}" -f $items.Count) -ForegroundColor Cyan

    if ($items.Count -eq 0) {
        Write-Host "  [!] Стратегий не найдено" -ForegroundColor Yellow
        return @()
    }

    $withScore = @($items | Where-Object { $_.Total -gt 0 })
    if ($withScore.Count -gt 0) {
        $ideal = @($withScore | Where-Object { $_.Score -eq $_.Total }).Count
        $good  = @($withScore | Where-Object { $_.Percent -ge 75 -and $_.Score -ne $_.Total }).Count
        $weak  = @($withScore | Where-Object { $_.Percent -lt 75 }).Count
        $avgScore = [math]::Round(($withScore | Measure-Object -Property Score -Average).Average, 1)
        $avgTotal = [math]::Round(($withScore | Measure-Object -Property Total -Average).Average, 1)

        Write-Host ("    IDEAL (100%):  {0}" -f $ideal) -ForegroundColor Green
        Write-Host ("    GOOD  (>=75%): {0}" -f $good)  -ForegroundColor Yellow
        Write-Host ("    WEAK  (<75%):  {0}" -f $weak)  -ForegroundColor DarkGray
        Write-Host ("    Средний скор:  {0}/{1}" -f $avgScore, $avgTotal) -ForegroundColor Gray
    }

    return $items
}

function Save-ResultatFile {
    param(
        [string]$ResultFile,
        [object[]]$Strategies
    )

    if ($Strategies.Count -eq 0) { return }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# ===============================================================")
    [void]$sb.AppendLine("# Zapret Manager - resultat.txt")
    [void]$sb.AppendLine("# Дата: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# Стратегий: $($Strategies.Count)")
    [void]$sb.AppendLine("# ===============================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine(":: ЛУЧШИЕ СТРАТЕГИИ")
    [void]$sb.AppendLine("")

    $rank = 0
    foreach ($s in $Strategies) {
        $rank++
        [void]$sb.AppendLine(("# #{0}  [{1}/{2}]  {3}" -f $rank, $s.Score, $s.Total, $s.Method))
        [void]$sb.AppendLine("--new")
        [void]$sb.AppendLine($s.Cmd)
        [void]$sb.AppendLine("")
    }

    Set-Content -Path $ResultFile -Value $sb.ToString() -Encoding UTF8
    Write-Log ("resultat.txt обновлён: {0} стратегий" -f $Strategies.Count) "INFO"
}

function Invoke-VerifyScan {
    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Cyan
    Write-Host "               ZAPRET -- VERIFY (перепроверка)" -ForegroundColor Cyan
    Write-Host "  ==============================================================" -ForegroundColor Cyan

    if (-not (Test-Admin)) {
        Write-Log "Нужны права администратора" "ERR"
        return
    }

    $usRoot       = Split-Path $PSScriptRoot -Parent
    $resultDir    = Join-Path $usRoot 'resultats'
    $resultatFile = Join-Path $resultDir 'resultat.txt'
    $pretestFile  = Join-Path $resultDir 'pretest.txt'

    $pretestItems  = @(Show-FileStats -Path $pretestFile  -Title "PRETEST.TXT"  -Color DarkYellow)
    $resultatItems = @(Show-FileStats -Path $resultatFile -Title "RESULTAT.TXT" -Color Green)

    $sourceItems = @()
    $sourceName  = ""

    if ($pretestItems.Count -gt 0 -and $resultatItems.Count -eq 0) {
        Write-Host ""
        Write-Host ("  [!] resultat.txt пуст, но pretest.txt содержит {0} стратегий" -f $pretestItems.Count) -ForegroundColor Yellow
        Write-Host "      Буду проверять pretest.txt и промоутить годные в resultat.txt" -ForegroundColor Yellow
        $sourceItems = $pretestItems
        $sourceName  = "pretest.txt"
    }
    elseif ($pretestItems.Count -eq 0 -and $resultatItems.Count -eq 0) {
        Write-Host ""
        Write-Log "В pretest.txt нет стратегий для перепроверки" "WARN"
        Write-Log "Сначала запусти пункт 8 (АВТО-ТЕСТ)" "WARN"
        Read-Host "  Enter..."
        return
    }
    elseif ($pretestItems.Count -eq 0 -and $resultatItems.Count -gt 0) {
        Write-Host ""
        Write-Host ("  [!] pretest.txt пуст, буду проверять resultat.txt ({0} стратегий)" -f $resultatItems.Count) -ForegroundColor Yellow
        $sourceItems = $resultatItems
        $sourceName  = "resultat.txt"
    }
    else {
        Write-Host ""
        Write-Host "  --- Что проверять ---" -ForegroundColor DarkCyan
        Write-Host ("    1. PRETEST.TXT   ({0} стратегий, черновик)" -f $pretestItems.Count) -ForegroundColor Yellow
        Write-Host ("    2. RESULTAT.TXT  ({0} стратегий, финал)"   -f $resultatItems.Count) -ForegroundColor Green
        Write-Host "    0. Отмена"
        Write-Host ""
        $src = Read-Host "  Выбор"

        if ($src -eq '0') { return }
        elseif ($src -eq '1') {
            $sourceItems = $pretestItems
            $sourceName  = "pretest.txt"
        } else {
            $sourceItems = $resultatItems
            $sourceName  = "resultat.txt"
        }
    }

    Write-Host ""
    Write-Host ("  Источник: {0} ({1} стратегий)" -f $sourceName, $sourceItems.Count) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Режим:" -ForegroundColor DarkGray
    Write-Host "      1. Быстрая проверка (первые 10 доменов)"
    Write-Host "      2. Полная проверка (все домены)"
    Write-Host "      3. Только одна стратегия (по номеру)"
    Write-Host "      0. Отмена"
    Write-Host ""
    $mode = Read-Host "  Выбор"

    if ($mode -eq '0') { return }

    $toCheck = @()
    if ($mode -eq '3') {
        Write-Host ""
        $i = 0
        foreach ($s in $sourceItems) {
            $i++
            $short = if ($s.Method.Length -gt 80) { $s.Method.Substring(0, 77) + '...' } else { $s.Method }
            Write-Host ("    [{0,2}] [{1,2}/{2}] {3,5}%  {4}" -f $i, $s.Score, $s.Total, $s.Percent, $short)
        }
        Write-Host ""
        $sel = Read-Host "  Номер стратегии"
        $n = 0
        if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le $sourceItems.Count) {
            $toCheck = @($sourceItems[$n - 1])
        } else {
            Write-Log "Неверный номер" "ERR"
            return
        }
    } else {
        $toCheck = $sourceItems
    }

    if ($mode -eq '1') {
        $domains = @(Get-DomainsFromHostlist -Max 10)
    } else {
        $domains = @(Get-DomainsFromHostlist -Max 0)
    }

    if ($domains.Count -eq 0) {
        Write-Log "Нет доменов для проверки" "ERR"
        Read-Host "  Enter..."
        return
    }

    Write-Host ""
    Write-Host ("  Доменов:   {0}" -f $domains.Count) -ForegroundColor Gray
    Write-Host ("  Стратегий: {0}" -f $toCheck.Count) -ForegroundColor Gray
    Write-Host ""

    $results = New-Object System.Collections.Generic.List[object]
    $promote = New-Object System.Collections.Generic.List[object]
    $startTime = Get-Date
    $i = 0

    foreach ($s in $toCheck) {
        $i++
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $eta = if ($i -gt 1) { [math]::Round(($elapsed/($i-1))*($toCheck.Count-$i+1)/60, 1) } else { '?' }

        Write-Host ""
        Write-Host ("  [{0,2}/{1}] ETA {2} мин" -f $i, $toCheck.Count, $eta) -ForegroundColor Cyan
        Write-Host ("    Старый: [{0}/{1}] {2}%" -f $s.Score, $s.Total, $s.Percent) -ForegroundColor DarkGray
        Write-Host ("    {0}" -f $s.Method) -ForegroundColor DarkGray
        Write-Host "    Запускаю winws..." -ForegroundColor DarkCyan

        $r = Test-Strategy -StrategyLine $s.Cmd -Domains $domains
        if ($r) {
            $newScore = $r.Score
            $newTotal = $r.Total
            $newPct   = if ($newTotal -gt 0) { [math]::Round($newScore / $newTotal * 100, 1) } else { 0 }

            $col = if ($newScore -eq $newTotal -and $newTotal -gt 0) { 'Green' }
                   elseif ($newPct -ge 75) { 'Yellow' }
                   else { 'White' }

            Write-Host ("    Новый:  [{0}/{1}] {2}%" -f $newScore, $newTotal, $newPct) -ForegroundColor $col

            $minPct = [double]$Global:ZapretState.MinScorePercent
            $passes = ($newScore -ge $Global:ZapretState.MinScore) -and
                      ($minPct -le 0 -or $newPct -ge $minPct)

            if ($passes) {
                Write-Host "    [PROMOTE] Прошёл фильтр -> попадает в resultat.txt" -ForegroundColor Green
                $promote.Add([pscustomobject]@{
                    Score   = $newScore
                    Total   = $newTotal
                    Percent = $newPct
                    Method  = $s.Method
                    Cmd     = $s.Cmd
                }) | Out-Null
            } else {
                Write-Host ("    [SKIP] Не прошёл: Score={0}, Pct={1}%" -f $newScore, $newPct) -ForegroundColor DarkGray
            }

            $results.Add([pscustomobject]@{
                Rank     = $s.Rank
                OldScore = $s.Score
                OldTotal = $s.Total
                OldPct   = $s.Percent
                NewScore = $newScore
                NewTotal = $newTotal
                NewPct   = $newPct
                Diff     = $newScore - $s.Score
                Method   = $s.Method
                Cmd      = $s.Cmd
            }) | Out-Null
        } else {
            Write-Host "    [!] Не удалось запустить winws" -ForegroundColor Red
        }
    }

    $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)

    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Cyan
    Write-Host "                    ИТОГИ ПЕРЕПРОВЕРКИ" -ForegroundColor Cyan
    Write-Host "  ==============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  Время:          {0} мин" -f $totalTime) -ForegroundColor Gray
    Write-Host ("  Проверено:      {0}" -f $results.Count) -ForegroundColor Gray
    Write-Host ("  Прошли фильтр:  {0}" -f $promote.Count) -ForegroundColor Green
    Write-Host ""

    if ($results.Count -eq 0) {
        Read-Host "  Enter..."
        return
    }

    Write-Host ("    {0,-4} {1,-14} {2,-14} {3,-10}" -f "#", "Старый", "Новый", "Разница") -ForegroundColor DarkGray
    Write-Host ("    " + ("-" * 55)) -ForegroundColor DarkGray

    foreach ($r in $results) {
        $diffStr = if ($r.Diff -gt 0) { "+$($r.Diff)" } elseif ($r.Diff -lt 0) { "$($r.Diff)" } else { "0" }
        $col = if ($r.Diff -gt 0) { 'Green' } elseif ($r.Diff -lt 0) { 'Red' } else { 'Gray' }
        Write-Host ("    {0,-4} {1,-14} {2,-14} {3,-10}" -f `
            $r.Rank,
            ("[{0}/{1}] {2}%" -f $r.OldScore, $r.OldTotal, $r.OldPct),
            ("[{0}/{1}] {2}%" -f $r.NewScore, $r.NewTotal, $r.NewPct),
            $diffStr) -ForegroundColor $col
    }
    Write-Host ""

    if ($promote.Count -gt 0) {
        Write-Host "  --- Промоут в resultat.txt ---" -ForegroundColor DarkCyan
        Write-Host ("    Кандидатов: {0}" -f $promote.Count) -ForegroundColor Green
        Write-Host ""
        Write-Host "  Записать их в resultat.txt? (Y/N): " -NoNewline -ForegroundColor Cyan
        $ans = Read-Host
        if ($ans -match '^[YyДд]') {
            $sorted = @($promote | Sort-Object -Property @{Expression={$_.Score};Descending=$true})
            Save-ResultatFile -ResultFile $resultatFile -Strategies $sorted
            Write-Host ""
            Write-Log ("Записано в resultat.txt: {0} стратегий" -f $sorted.Count) "INFO"
        }
    } else {
        Write-Host "  Ни одна стратегия не прошла фильтр — resultat.txt не изменён" -ForegroundColor DarkYellow
    }

    $verifyFile = Join-Path $resultDir 'verify.txt'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# ===============================================================")
    [void]$sb.AppendLine("# Zapret Manager - verify.txt")
    [void]$sb.AppendLine("# Дата: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# Источник: $sourceName")
    [void]$sb.AppendLine("# Доменов: $($domains.Count)")
    [void]$sb.AppendLine("# Проверено: $($results.Count)")
    [void]$sb.AppendLine("# Прошли фильтр: $($promote.Count)")
    [void]$sb.AppendLine("# ===============================================================")
    [void]$sb.AppendLine("")
    foreach ($r in $results) {
        $diffStr = if ($r.Diff -gt 0) { "+$($r.Diff)" } elseif ($r.Diff -lt 0) { "$($r.Diff)" } else { "0" }
        [void]$sb.AppendLine(("# #{0}  old=[{1}/{2}] new=[{3}/{4}] diff={5}" -f `
            $r.Rank, $r.OldScore, $r.OldTotal, $r.NewScore, $r.NewTotal, $diffStr))
        [void]$sb.AppendLine(("#   {0}" -f $r.Method))
        [void]$sb.AppendLine("")
    }
    Set-Content -Path $verifyFile -Value $sb.ToString() -Encoding UTF8

    Write-Host ""
    Write-Host ("  Отчёт: {0}" -f $verifyFile) -ForegroundColor Green
    Write-Host ""
    Read-Host "  Enter..."
}

function Show-ResultsStats {
    $usRoot    = Split-Path $PSScriptRoot -Parent
    $resultDir = Join-Path $usRoot 'resultats'
    $resultat  = Join-Path $resultDir 'resultat.txt'
    $pretest   = Join-Path $resultDir 'pretest.txt'

    Clear-Host
    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Cyan
    Write-Host "                 ZAPRET -- СТАТИСТИКА РЕЗУЛЬТАТОВ" -ForegroundColor Cyan
    Write-Host "  ==============================================================" -ForegroundColor Cyan

    $null = Show-FileStats -Path $pretest  -Title "PRETEST.TXT  (черновик)"  -Color DarkYellow
    $null = Show-FileStats -Path $resultat -Title "RESULTAT.TXT (готовые)"   -Color Green

    Write-Host ""
    Read-Host "  Enter..."
}