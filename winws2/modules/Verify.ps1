# ===============================================================
# === VERIFY (Verify.ps1) — winws2 / zapret2 ===
# ===============================================================
#  Пункт 28 (Invoke-VerifyScan) — что можно ввести:
#    [Enter]        → перепроверить pretest.txt / resultat.txt
#    путь к .txt    → полный .txt-конфиг winws2
#    1              → одну строку стратегии (вручную)
#    2              → ИЗ БУФЕРА ОБМЕНА (скопировал Ctrl+C → Enter)
#    3              → через Notepad (открыть, вставить, сохранить)
#    0              → отмена
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

    if ($list.Count -eq 0 -or $Kind -eq "pretest") {
        $i = 0
        $curScore = 0; $curTotal = 0; $curMethod = ""

        while ($i -lt $lines.Count) {
            $l = $lines[$i].Trim()

            if ($l -match '^#\s*.*?Score:\s*(\d+)/(\d+)\s*$') {
                $curScore = [int]$Matches[1]; $curTotal = [int]$Matches[2]
                $curMethod = ""; $i++; continue
            }
            if ($l -match '^#\s*.*?\[(\d+)/(\d+)\]\s*(.*)$') {
                $curScore = [int]$Matches[1]; $curTotal = [int]$Matches[2]
                $curMethod = $Matches[3].Trim(); $i++; continue
            }
            if ($l -eq '--new') {
                for ($j = $i + 1; $j -lt $lines.Count -and $j -lt ($i + 6); $j++) {
                    $c = $lines[$j].Trim()
                    if ($c -eq '' -or $c.StartsWith('#') -or $c.StartsWith('::') -or $c -eq '--new') { continue }
                    $m = if ($curMethod) { $curMethod } else { $c.Substring(0, [Math]::Min(80, $c.Length)) }
                    $list.Add([pscustomobject]@{
                        Rank = $list.Count + 1; Score = $curScore; Total = $curTotal
                        Percent = if ($curTotal -gt 0) { [math]::Round($curScore / $curTotal * 100, 1) } else { 0 }
                        Method = $m; Cmd = $c
                    }) | Out-Null
                    $curScore = 0; $curTotal = 0; $curMethod = ""
                    $i = $j; break
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

    $info  = Get-Item $Path
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
    [void]$sb.AppendLine("# Zapret Manager 2 (winws2) - resultat.txt")
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

# ============================================================================
#  ВСПОМОГАТЕЛЬНЫЕ
# ============================================================================

function Add-Winws2Prelude {
    param([string]$Line)

    $prelude = @()
    if ($Line -notmatch '(^|\s)--wf-') {
        $prelude += "--wf-tcp-out=443 --wf-tcp-in=443 --wf-udp-out=443 --wf-udp-in=443"
    }
    if ($Line -notmatch '--lua-init') {
        $luaInit = Get-Winws2LuaInit
        if ($luaInit) { $prelude += $luaInit }
    }
    if ($Line -notmatch '--blob=') {
        $blobDefs = Get-Winws2BlobDefs
        if ($blobDefs) { $prelude += $blobDefs }
    }
    if ($prelude.Count -eq 0) { return $Line }
    return (($prelude -join ' ') + ' ' + $Line).Trim()
}

# Склеить МНОГОСТРОЧНЫЙ текст в одну строку winws2
function Convert-MultilineToWinws2 {
    param([string]$Text)

    if (-not $Text) { return "" }

    $lines = $Text -split "`r?`n"
    $parts = @()
    foreach ($l in $lines) {
        $t = $l.Trim()
        if (-not $t) { continue }
        if ($t.StartsWith('#') -or $t.StartsWith('::')) { continue }
        if ($t -eq '--new') { continue }
        $parts += $t
    }
    if ($parts.Count -eq 0) { return "" }
    return ($parts -join ' ')
}

function Read-MaxDomains {
    Write-Host ""
    Write-Host "  Сколько доменов использовать?" -ForegroundColor DarkCyan
    Write-Host "    [Enter] = все домены из hostlist" -ForegroundColor DarkGray
    Write-Host "    <число> = первые N" -ForegroundColor DarkGray
    $maxStr = (Read-Host "  N").Trim()
    $maxN = 0
    if ($maxStr) { [void][int]::TryParse($maxStr, [ref]$maxN) }
    return $maxN
}

# ============================================================================
#  ГЛАВНАЯ ФУНКЦИЯ ПУНКТА 28
# ============================================================================
function Invoke-VerifyScan {
    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "         ZAPRET 2 (winws2) -- VERIFY (перепроверка)" -ForegroundColor Magenta
    Write-Host "  ==============================================================" -ForegroundColor Magenta

    if (-not (Test-Admin)) {
        Write-Log "Нужны права администратора" "ERR"
        return
    }

    $root         = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
    $resultDir    = Join-Path $root 'resultats'
    $resultatFile = Join-Path $resultDir 'resultat.txt'
    $pretestFile  = Join-Path $resultDir 'pretest.txt'

    $null = Show-FileStats -Path $pretestFile  -Title "PRETEST.TXT"  -Color DarkYellow
    $null = Show-FileStats -Path $resultatFile -Title "RESULTAT.TXT" -Color Green

    Write-Host ""
    Write-Host "  ─── Что проверить ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "    [Enter]        = перепроверить pretest.txt / resultat.txt" -ForegroundColor Gray
    Write-Host "    <путь к .txt>  = полный конфиг winws2 из файла" -ForegroundColor Cyan
    Write-Host "    1              = одну строку (ввести вручную)" -ForegroundColor Yellow
    Write-Host "    2              = ИЗ БУФЕРА ОБМЕНА (скопировал Ctrl+C → Enter)" -ForegroundColor Green
    Write-Host "    3              = через Notepad (открыть, вставить, сохранить)" -ForegroundColor Yellow
    Write-Host "    0              = отмена"
    Write-Host ""

    $mode = (Read-Host "  Ввод").Trim()

    if ($mode -eq '0') { return }

    $manualLine = $null

    # ═══ Путь к .txt файлу ═══
    if ($mode -and (Test-Path -LiteralPath $mode.Trim('"').Trim("'") -PathType Leaf) -and
        ((Get-Item -LiteralPath $mode.Trim('"').Trim("'")).Extension.ToLower() -eq '.txt')) {

        $cfgPath = $mode.Trim('"').Trim("'")
        Write-Host ""
        Write-Host ("  Файл: {0}" -f $cfgPath) -ForegroundColor Cyan

        $rawText = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8)
        $rawLine = Convert-MultilineToWinws2 -Text $rawText
        if (-not $rawLine) {
            Write-Log "В файле нет активных строк" "ERR"
            Read-Host "  Enter..."; return
        }
        $manualLine = Add-Winws2Prelude -Line $rawLine
        Write-Host ("  Собрано: {0} символов" -f $manualLine.Length) -ForegroundColor DarkGray
    }
    # ═══ 1 — одна строка ═══
    elseif ($mode -eq '1') {
        Write-Host ""
        Write-Host "  Вставь ОДНУ строку стратегии целиком (с --wf-, --lua-init, --blob, --filter-, --lua-desync)." -ForegroundColor DarkCyan
        Write-Host ""
        $rawLine = (Read-Host "  Строка").Trim()
        if (-not $rawLine) {
            Write-Log "Пустая строка — отмена" "WARN"; Read-Host "  Enter..."; return
        }
        $manualLine = Add-Winws2Prelude -Line $rawLine
    }
    # ═══ 2 — из буфера обмена ═══
    elseif ($mode -eq '2') {
        Write-Host ""
        Write-Host "  ─── Из буфера обмена ─────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  1. Скопируй блок строк в любом редакторе/браузере (Ctrl+C)." -ForegroundColor Gray
        Write-Host "  2. Вернись в это окно." -ForegroundColor Gray
        Write-Host "  3. Нажми Enter — скрипт сам прочитает буфер." -ForegroundColor Gray
        Write-Host ""
        Read-Host "  Нажми Enter, когда блок уже скопирован"

        try {
            $clip = Get-Clipboard -Raw -ErrorAction Stop
        } catch {
            Write-Log ("Не удалось прочитать буфер обмена: {0}" -f $_.Exception.Message) "ERR"
            Write-Host "  Fallback: сохрани блок в .txt и передай путь через ввод." -ForegroundColor Yellow
            Read-Host "  Enter..."; return
        }

        if (-not $clip) {
            Write-Log "Буфер обмена пуст" "ERR"
            Read-Host "  Enter..."; return
        }

        Write-Host ("  Буфер: {0} строк, {1} символов" -f (($clip -split "`r?`n").Count), $clip.Length) -ForegroundColor DarkGray

        $rawLine = Convert-MultilineToWinws2 -Text $clip
        if (-not $rawLine) {
            Write-Log "В буфере нет активных строк" "ERR"
            Read-Host "  Enter..."; return
        }
        $manualLine = Add-Winws2Prelude -Line $rawLine
        Write-Host ("  Собрано: {0} символов" -f $manualLine.Length) -ForegroundColor DarkGray
    }
    # ═══ 3 — через Notepad ═══
    elseif ($mode -eq '3') {
        Write-Host ""
        Write-Host "  ─── Через Notepad ────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  Сейчас откроется блокнот. Вставь блок, СОХРАНИ (Ctrl+S), закрой." -ForegroundColor Gray
        Write-Host ""

        $tmp = Join-Path $env:TEMP ("zm-verify-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".txt")
        [System.IO.File]::WriteAllText($tmp, "", [Text.UTF8Encoding]::new($false))

        try {
            Start-Process -FilePath "notepad.exe" -ArgumentList "`"$tmp`"" -Wait
        } catch {
            Write-Log ("Не удалось запустить notepad: {0}" -f $_.Exception.Message) "ERR"
            Read-Host "  Enter..."; return
        }

        if (-not (Test-Path $tmp)) {
            Write-Log "Временный файл не найден" "ERR"
            Read-Host "  Enter..."; return
        }

        $rawText = [System.IO.File]::ReadAllText($tmp, [System.Text.Encoding]::UTF8)
        $rawLine = Convert-MultilineToWinws2 -Text $rawText
        if (-not $rawLine) {
            Write-Log "Файл пуст или без активных строк" "ERR"
            try { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } catch {}
            Read-Host "  Enter..."; return
        }
        $manualLine = Add-Winws2Prelude -Line $rawLine
        Write-Host ("  Собрано: {0} символов" -f $manualLine.Length) -ForegroundColor DarkGray
        try { Remove-Item $tmp -Force -ErrorAction SilentlyContinue } catch {}
    }
    # ═══ Пусто — режим файлов ═══
    else {
        # тут ничего — пойдём в блок "перепроверка файлов"
    }

    # ═══════════════════════════════════════════════════════════════
    #  РУЧНОЙ ЗАПУСК
    # ═══════════════════════════════════════════════════════════════
    if ($manualLine) {
        $maxN = Read-MaxDomains
        $domains = @(Get-DomainsFromHostlist -Max $maxN)
        if ($domains.Count -eq 0) {
            Write-Log "Нет доменов" "ERR"; Read-Host "  Enter..."; return
        }

        Write-Host ""
        Write-Host ("  Запускаю winws2 на {0} доменах..." -f $domains.Count) -ForegroundColor DarkMagenta
        Write-Host ""

        $r = Test-Strategy -StrategyLine $manualLine -Domains $domains
        if (-not $r) {
            Write-Log "winws2 не запустился (ошибка в строке?)" "ERR"
            Read-Host "  Enter..."; return
        }

        $pct = if ($r.Total -gt 0) { [math]::Round($r.Score / $r.Total * 100, 1) } else { 0 }
        Write-Host ""
        Write-Host ("  Итог: [{0}/{1}]  {2}%" -f $r.Score, $r.Total, $pct) -ForegroundColor $(
            if ($r.Score -eq $r.Total -and $r.Total -gt 0) { 'Green' }
            elseif ($pct -ge 75) { 'Yellow' }
            else { 'White' }
        )

        Write-Host ""
        Write-Host "  Записать в resultat.txt? (Y/N): " -NoNewline -ForegroundColor Cyan
        $ans = Read-Host
        if ($ans -match '^[YyДд]') {
            $existing = @(Get-StrategiesFromFile -Path $resultatFile)
            $all = @($existing + [pscustomobject]@{
                Score = $r.Score; Total = $r.Total; Percent = $pct
                Method = "(manual)"; Cmd = $manualLine
            })
            Save-ResultatFile -ResultFile $resultatFile -Strategies $all
            Write-Host ("  [OK] Добавлено. Всего: {0}" -f $all.Count) -ForegroundColor Green
        }
        Read-Host "  Enter..."
        return
    }

    # ═══════════════════════════════════════════════════════════════
    #  ПЕРЕПРОВЕРКА ФАЙЛОВ
    # ═══════════════════════════════════════════════════════════════
    $pretestItems  = @(Get-StrategiesFromFile -Path $pretestFile)
    $resultatItems = @(Get-StrategiesFromFile -Path $resultatFile)

    $sourceItems = @()
    $sourceName  = ""

    if ($pretestItems.Count -gt 0 -and $resultatItems.Count -eq 0) {
        Write-Host ""
        Write-Host ("  [!] resultat.txt пуст, но pretest.txt содержит {0} стратегий" -f $pretestItems.Count) -ForegroundColor Yellow
        $sourceItems = $pretestItems; $sourceName = "pretest.txt"
    }
    elseif ($pretestItems.Count -eq 0 -and $resultatItems.Count -eq 0) {
        Write-Host ""
        Write-Log "В pretest.txt нет стратегий для перепроверки" "WARN"
        Write-Log "Сначала запусти пункт 10 (АВТО-ТЕСТ)" "WARN"
        Read-Host "  Enter..."
        return
    }
    elseif ($pretestItems.Count -eq 0 -and $resultatItems.Count -gt 0) {
        Write-Host ""
        Write-Host ("  [!] pretest.txt пуст, буду проверять resultat.txt ({0} стратегий)" -f $resultatItems.Count) -ForegroundColor Yellow
        $sourceItems = $resultatItems; $sourceName = "resultat.txt"
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
        elseif ($src -eq '1') { $sourceItems = $pretestItems; $sourceName = "pretest.txt" }
        else                  { $sourceItems = $resultatItems; $sourceName = "resultat.txt" }
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
    $modeChk = Read-Host "  Выбор"

    if ($modeChk -eq '0') { return }

    $toCheck = @()
    if ($modeChk -eq '3') {
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
            Write-Log "Неверный номер" "ERR"; return
        }
    } else {
        $toCheck = $sourceItems
    }

    if ($modeChk -eq '1') { $domains = @(Get-DomainsFromHostlist -Max 10) }
    else                  { $domains = @(Get-DomainsFromHostlist -Max 0) }

    if ($domains.Count -eq 0) {
        Write-Log "Нет доменов для проверки" "ERR"; Read-Host "  Enter..."; return
    }

    Write-Host ""
    Write-Host ("  Доменов:   {0}" -f $domains.Count) -ForegroundColor Gray
    Write-Host ("  Стратегий: {0}" -f $toCheck.Count) -ForegroundColor Gray
    Write-Host ""

    $results   = New-Object System.Collections.Generic.List[object]
    $promote   = New-Object System.Collections.Generic.List[object]
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
        Write-Host "    Запускаю winws2..." -ForegroundColor DarkMagenta

        $r = Test-Strategy -StrategyLine $s.Cmd -Domains $domains
        if ($r) {
            $newScore = $r.Score
            $newTotal = $r.Total
            $newPct   = if ($newTotal -gt 0) { [math]::Round($newScore / $newTotal * 100, 1) } else { 0 }

            $col = if ($newScore -eq $newTotal -and $newTotal -gt 0) { 'Green' }
                   elseif ($newPct -ge 75) { 'Yellow' } else { 'White' }

            Write-Host ("    Новый:  [{0}/{1}] {2}%" -f $newScore, $newTotal, $newPct) -ForegroundColor $col

            $minPct = [double]$Global:ZapretState.MinScorePercent
            $passes = ($newScore -ge $Global:ZapretState.MinScore) -and
                      ($minPct -le 0 -or $newPct -ge $minPct)

            if ($passes) {
                Write-Host "    [PROMOTE] Прошёл фильтр -> попадает в resultat.txt" -ForegroundColor Green
                $promote.Add([pscustomobject]@{
                    Score = $newScore; Total = $newTotal; Percent = $newPct
                    Method = $s.Method; Cmd = $s.Cmd
                }) | Out-Null
            } else {
                Write-Host ("    [SKIP] Не прошёл: Score={0}, Pct={1}%" -f $newScore, $newPct) -ForegroundColor DarkGray
            }

            $results.Add([pscustomobject]@{
                Rank = $s.Rank; OldScore = $s.Score; OldTotal = $s.Total; OldPct = $s.Percent
                NewScore = $newScore; NewTotal = $newTotal; NewPct = $newPct
                Diff = $newScore - $s.Score; Method = $s.Method; Cmd = $s.Cmd
            }) | Out-Null
        } else {
            Write-Host "    [!] Не удалось запустить winws2" -ForegroundColor Red
        }
    }

    $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)

    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "                    ИТОГИ ПЕРЕПРОВЕРКИ" -ForegroundColor Magenta
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host ("  Время:          {0} мин" -f $totalTime) -ForegroundColor Gray
    Write-Host ("  Проверено:      {0}" -f $results.Count) -ForegroundColor Gray
    Write-Host ("  Прошли фильтр:  {0}" -f $promote.Count) -ForegroundColor Green
    Write-Host ""

    if ($results.Count -eq 0) { Read-Host "  Enter..."; return }

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
    [void]$sb.AppendLine("# Zapret Manager 2 (winws2) - verify.txt")
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
    $root      = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
    $resultDir = Join-Path $root 'resultats'
    $resultat  = Join-Path $resultDir 'resultat.txt'
    $pretest   = Join-Path $resultDir 'pretest.txt'

    Clear-Host
    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Magenta
    Write-Host "         ZAPRET 2 (winws2) -- СТАТИСТИКА РЕЗУЛЬТАТОВ" -ForegroundColor Magenta
    Write-Host "  ==============================================================" -ForegroundColor Magenta

    $null = Show-FileStats -Path $pretest  -Title "PRETEST.TXT  (черновик)" -Color DarkYellow
    $null = Show-FileStats -Path $resultat -Title "RESULTAT.TXT (готовые)"  -Color Green

    Write-Host ""
    Read-Host "  Enter..."
}