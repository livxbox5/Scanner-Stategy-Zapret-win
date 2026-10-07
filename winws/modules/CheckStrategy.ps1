# ===============================================================
# === CHECK STRATEGY (CheckStrategy.ps1) ===
# ===============================================================
#  Проверка стратегий из .bat, вставленных вручную в консоль.
#  2 РЕЖИМА:
#    Режим 1 (bat):  полный .bat с "winws.exe ..." → 1 стратегия
#    Режим 2 (strategies):  strategies.bat (--new-блоки) → N стратегий
#
#  Запуск winws идёт через ВРЕМЕННЫЙ .bat (CP866) + cmd /c —
#  это гарантирует, что кавычки и пути не будут испорчены PowerShell.
#
#  Проверка идёт как браузер: HTTP/2, HTTP/3 (QUIC), www-фолбэк,
#  классификация домена относительно baseline (NEW/KEPT/LOST/STILL).
# ===============================================================

# === GET-BATVARIABLESFROMTEXT ===
function Get-BatVariablesFromText {
    param([string]$Text)
    $vars = @{}
    if (-not $Text) { return $vars }
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*set\s+"?([A-Za-z_][A-Za-z0-9_]*)=(.*?)"?\s*$') {
            $vars[$Matches[1]] = $Matches[2].TrimEnd('"')
        }
    }
    return $vars
}

# === RESOLVE-BATVALUE ===
function Resolve-BatValue {
    param([string]$Value, [hashtable]$Vars, [string]$RootFwd, [int]$Depth = 0)
    if ($Depth -gt 6 -or -not $Value) { return $Value }

    $Value = $Value.Replace('%~dp0bin\',   ($RootFwd + 'bin/'))
    $Value = $Value.Replace('%~dp0lists\', ($RootFwd + 'lists/'))
    $Value = $Value.Replace('%~dp0',       $RootFwd)

    foreach ($m in [regex]::Matches($Value, '%([A-Za-z_][A-Za-z0-9_]*)%')) {
        $name = $m.Groups[1].Value
        if ($Vars.ContainsKey($name)) {
            $inner = Resolve-BatValue -Value $Vars[$name] -Vars $Vars -RootFwd $RootFwd -Depth ($Depth + 1)
            $Value = $Value.Replace($m.Value, $inner)
        }
    }
    return $Value
}

# === EXPAND-STRATEGYLINE ===
function Expand-StrategyLine {
    param([string]$Line, [hashtable]$Vars)
    if (-not $Line) { return $Line }

    $winwsPath = [string]$Global:ZapretState.WinwsPath
    $rootFwd = ''
    if ($winwsPath) {
        $binDir = Split-Path $winwsPath -Parent
        $root   = Split-Path $binDir  -Parent
        if ($root) { $rootFwd = ($root -replace '\\','/').TrimEnd('/') + '/' }
    }

    if (-not $Vars.ContainsKey('BIN') -and $Global:ZapretState.BinPath) {
        $Vars['BIN'] = ($Global:ZapretState.BinPath -replace '\\','/').TrimEnd('/') + '/'
    }
    if (-not $Vars.ContainsKey('LISTS') -and $Global:ZapretState.TxtPath) {
        $Vars['LISTS'] = ($Global:ZapretState.TxtPath -replace '\\','/').TrimEnd('/') + '/'
    }
    if (-not $Vars.ContainsKey('TCPPort')) { $Vars['TCPPort'] = '80,443,2053,2083,2087,2096,8443' }
    if (-not $Vars.ContainsKey('UDPPort')) { $Vars['UDPPort'] = '443,19294-19344,50000-50100' }

    $Line = Resolve-BatValue -Value $Line -Vars $Vars -RootFwd $rootFwd

    # Остатки %GameFilter*% (в --wf-tcp/--wf-udp) — выкидываем
    $Line = $Line -replace '%GameFilterTCP%', ''
    $Line = $Line -replace '%GameFilterUDP%', ''

    # Чистка: двойные/висячие запятые, лишние пробелы
    $Line = $Line -replace ',\s*,', ','
    $Line = $Line -replace ',\s*(?=\s|$)', ' '
    $Line = $Line -replace '\s+', ' '
    return $Line.Trim()
}

# === РЕЖИМ 1: полный .bat ===
function Get-Mode1Strategies {
    param([string]$Text, [hashtable]$Vars)

    $lines  = $Text -split "`r?`n"
    $merged = New-Object System.Collections.Generic.List[string]
    $cur = ""
    foreach ($ln in $lines) {
        $t = $ln.TrimEnd()
        if ($t.Trim() -eq "") { continue }
        if ($t.EndsWith("^")) {
            $cur += $t.Substring(0, $t.Length - 1) + " "
            continue
        }
        $cur += $t
        if ($cur.Trim()) { $merged.Add($cur.Trim()) }
        $cur = ""
    }
    if ($cur.Trim()) { $merged.Add($cur.Trim()) }

    $list = New-Object System.Collections.Generic.List[object]

    foreach ($line in $merged) {
        if ($line -notmatch '(?i)winws\.exe') { continue }
        $m = [regex]::Match($line, '(?i)winws\.exe"?\s+(.*)$')
        if (-not $m.Success) { continue }
        $rawArgs = $m.Groups[1].Value.Trim()
        if (-not $rawArgs) { continue }

        # Разбиваем на профили и выкидываем GameFilter-зависимые
        $profiles = $rawArgs -split '\s+--new\s+'
        $kept     = New-Object System.Collections.Generic.List[string]
        $skipped  = 0

        for ($k = 0; $k -lt $profiles.Count; $k++) {
            $p = $profiles[$k].Trim()
            if ($p -match '--filter-tcp\s*=\s*%GameFilterTCP%' -or
                $p -match '--filter-udp\s*=\s*%GameFilterUDP%') {
                $skipped++
                continue
            }
            if ($k -gt 0) { $p = '--new ' + $p }
            $kept.Add($p)
        }

        if ($skipped -gt 0) {
            Write-Host ("      [i] Пропущено {0} профилей с %GameFilter*%" -f $skipped) -ForegroundColor DarkYellow
        }

        $args = ($kept -join ' ').Trim()
        if (-not $args) { continue }

        $args = Expand-StrategyLine -Line $args -Vars $Vars
        if (-not $args) { continue }

        $unresolved = @()
        if ($args -match '%[A-Za-z_][A-Za-z0-9_]*%') {
            $unresolved = @(
                [regex]::Matches($args, '%[A-Za-z_][A-Za-z0-9_]*%') |
                ForEach-Object { $_.Value } | Select-Object -Unique
            )
        }

        $list.Add([pscustomobject]@{
            Mode       = 1
            Line       = $args
            Unresolved = $unresolved
            Length     = $args.Length
        }) | Out-Null
    }
    return $list.ToArray()
}

# === РЕЖИМ 2: strategies.bat ===
function Get-Mode2Strategies {
    param([string]$Text, [hashtable]$Vars)

    $lines = $Text -split "`r?`n"
    $list  = New-Object System.Collections.Generic.List[object]

    $i = 0
    while ($i -lt $lines.Count) {
        $l = $lines[$i].Trim()
        if ($l -ne '--new') { $i++; continue }

        $strategy = ""
        $j = $i + 1
        while ($j -lt $lines.Count) {
            $c = $lines[$j].Trim()
            if ($c -eq '') { $j++; continue }
            if ($c.StartsWith('::')) { break }
            if ($c.StartsWith('#'))  { break }
            if ($c -eq '--new')      { break }
            $strategy = $c
            break
        }

        if ($strategy) {
            if ($strategy -match '--filter-tcp\s*=\s*%GameFilterTCP%' -or
                $strategy -match '--filter-udp\s*=\s*%GameFilterUDP%') {
                Write-Host ("      [i] Пропускаю стратегию с %GameFilter*%") -ForegroundColor DarkYellow
                $i = $j + 1
                continue
            }

            $args = Expand-StrategyLine -Line $strategy -Vars $Vars
            if (-not $args) { $i = $j + 1; continue }

            $full = '--new ' + $args
            $unresolved = @()
            if ($full -match '%[A-Za-z_][A-Za-z0-9_]*%') {
                $unresolved = @(
                    [regex]::Matches($full, '%[A-Za-z_][A-Za-z0-9_]*%') |
                    ForEach-Object { $_.Value } | Select-Object -Unique
                )
            }

            $list.Add([pscustomobject]@{
                Mode       = 2
                Line       = $full
                Unresolved = $unresolved
                Length     = $full.Length
            }) | Out-Null
        }

        $i = $j + 1
    }
    return $list.ToArray()
}

# === АВТО-ОПРЕДЕЛЕНИЕ ===
function Get-AutoMode {
    param([string]$Text)
    if (-not $Text) { return 0 }
    if ($Text -match '(?i)winws\.exe')    { return 1 }
    if ($Text -match '(?m)^\s*--new\s*$') { return 2 }
    return 0
}

function Get-ClipStrategies {
    param([string]$Text, [int]$ForceMode = 0)
    if (-not $Text -or $Text.Trim() -eq '') { return @() }
    $mode = if ($ForceMode -in @(1,2)) { $ForceMode } else { Get-AutoMode -Text $Text }
    $batVars = Get-BatVariablesFromText -Text $Text
    switch ($mode) {
        1 { return Get-Mode1Strategies -Text $Text -Vars $batVars }
        2 { return Get-Mode2Strategies -Text $Text -Vars $batVars }
        default { return @() }
    }
}

# === ПРЕВЬЮ ===
function Show-StrategyPreview {
    param([object[]]$Strategies)
    if ($Strategies.Count -eq 0) { return }
    Write-Host ""
    Write-Host "  ─── Распарсенные стратегии ─────────────────────────────" -ForegroundColor DarkCyan
    $i = 0
    foreach ($s in $Strategies) {
        $i++
        Write-Host ("  [{0,2}] Режим {1} | длина {2}" -f $i, $s.Mode, $s.Length) -ForegroundColor White
        if ($s.Unresolved.Count -gt 0) {
            Write-Host ("      [!] нераскрытые: {0}" -f ($s.Unresolved -join ', ')) -ForegroundColor Yellow
        }
        $show = $s.Line
        if ($show.Length -gt 220) { $show = $show.Substring(0, 217) + '...' }
        Write-Host ("      {0}" -f $show) -ForegroundColor DarkGray
    }
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
}

# === READ-MULTILINEFROMCONSOLE ===
function Read-MultilineFromConsole {
    Write-Host ""
    Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  1) Открой .bat в блокноте" -ForegroundColor Yellow
    Write-Host "  2) Ctrl+A → Ctrl+C" -ForegroundColor Yellow
    Write-Host "  3) Вернись сюда, щёлкни ПКМ по консоли (или Ctrl+V)" -ForegroundColor Yellow
    Write-Host "  4) Нажми Enter" -ForegroundColor Yellow
    Write-Host "  5) Ещё раз Enter (пустая строка = конец ввода)" -ForegroundColor Yellow
    Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""

    $lines       = New-Object System.Collections.Generic.List[string]
    $emptyStreak = 0
    while ($true) {
        $line = Read-Host
        if ([string]::IsNullOrWhiteSpace($line)) {
            $emptyStreak++
            if ($emptyStreak -ge 2 -and $lines.Count -gt 0) { break }
            continue
        }
        $emptyStreak = 0
        $lines.Add($line)
    }
    if ($lines.Count -eq 0) { return "" }
    return ($lines -join "`r`n")
}

# ═════════════════════════════════════════════════════════════
#  БРАУЗЕРО-ПОДОБНАЯ ПРОВЕРКА  (HTTP/2 + HTTP/3/QUIC + www)
# ═════════════════════════════════════════════════════════════

# Проверяет один раз, поддерживает ли curl ключ --http3
$script:CurlHttp3Supported = $null
function Test-CurlHttp3Support {
    if ($null -ne $script:CurlHttp3Supported) { return $script:CurlHttp3Supported }
    $tools = Get-HttpTool
    if (-not $tools.curl) {
        $script:CurlHttp3Supported = $false
        return $false
    }
    try {
        $help = (& $tools.curl --help all 2>&1 | Out-String)
        if ($help -match '--http3') { $script:CurlHttp3Supported = $true }
        else                        { $script:CurlHttp3Supported = $false }
    } catch {
        $script:CurlHttp3Supported = $false
    }
    return $script:CurlHttp3Supported
}

# Проверяет URL так, как это делал бы браузер:
#   1) curl --http2 + браузерный User-Agent
#   2) curl --http3 (QUIC/UDP), если curl поддерживает
#   3) Вариант с префиксом www. (если его не было)
#   4) iwr как fallback
# Возвращает объект с полем Mode (как именно удалось открыть).
function Test-EndpointLikeBrowser {
    param(
        [string]$Url,
        [int]$TimeoutSec = $Global:ZapretState.TimeoutSec
    )

    $result = [pscustomobject]@{
        Url    = $Url
        Ok     = $false
        Mode   = "fail"    # http2 | quic | www-http2 | www-quic | iwr | fail
        Msg    = ""
        Code   = ""
        TimeMs = 0
    }

    if (-not $Url) { return $result }

    $UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
          "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"

    # Выделяем хост из URL
    $hostName = $Url -replace '^https?://','' -replace '/.*$',''
    $hostName = $hostName -replace ':\d+$',''

    # Цели: original + www-вариант
    $targets = New-Object System.Collections.Generic.List[object]
    $targets.Add([pscustomobject]@{ Url = "https://$hostName"; Tag = "direct" })
    if ($hostName -notmatch '^www\.') {
        $targets.Add([pscustomobject]@{ Url = "https://www.$hostName"; Tag = "www" })
    }

    $tools = Get-HttpTool
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # ─── 1. curl --http2 (как современный браузер) ───
    if ($tools.curl) {
        foreach ($t in $targets) {
            $sw.Restart()
            $out  = & $tools.curl -s -o NUL -w "%{http_code}" `
                     --http2 --max-time $TimeoutSec `
                     -A $UA -L `
                     $t.Url 2>&1
            $code = "$out".Trim()
            $sw.Stop()

            if ($code -match '^\d{3}$' -and $code -ne '000') {
                $result.Ok     = $true
                $result.Code   = $code
                $result.Mode   = if ($t.Tag -eq "www") { "www-http2" } else { "http2" }
                $result.Msg    = "HTTP $code"
                $result.TimeMs = $sw.ElapsedMilliseconds
                return $result
            }
        }
    }

    # ─── 2. curl --http3 (QUIC/UDP) ───
    if ($tools.curl -and (Test-CurlHttp3Support)) {
        foreach ($t in $targets) {
            $sw.Restart()
            $out  = & $tools.curl -s -o NUL -w "%{http_code}" `
                     --http3 --max-time $TimeoutSec `
                     -A $UA -L `
                     $t.Url 2>&1
            $code = "$out".Trim()
            $sw.Stop()

            if ($code -match '^\d{3}$' -and $code -ne '000') {
                $result.Ok     = $true
                $result.Code   = $code
                $result.Mode   = if ($t.Tag -eq "www") { "www-quic" } else { "quic" }
                $result.Msg    = "HTTP3 $code"
                $result.TimeMs = $sw.ElapsedMilliseconds
                return $result
            }
        }
    }

    # ─── 3. Fallback: iwr ───
    foreach ($t in $targets) {
        try {
            $resp = Invoke-WebRequest -Uri $t.Url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
            $result.Ok   = $true
            $result.Code = "$($resp.StatusCode)"
            $result.Mode = if ($t.Tag -eq "www") { "www-iwr" } else { "iwr" }
            $result.Msg  = "HTTP $($resp.StatusCode)"
            return $result
        } catch [System.Net.WebException] {
            if ($_.Exception.Response) {
                $result.Ok   = $true
                $result.Code = "$([int]$_.Exception.Response.StatusCode)"
                $result.Mode = if ($t.Tag -eq "www") { "www-iwr" } else { "iwr" }
                $result.Msg  = "HTTP $($result.Code)"
                return $result
            }
        } catch { }
    }

    $result.Mode = "fail"
    $result.Msg  = "нет соединения"
    return $result
}

# ═════════════════════════════════════════════════════════════
#  ЗАПУСК WINWS ЧЕРЕЗ ВРЕМЕННЫЙ .BAT  (CP866 + cmd /c)
# ═════════════════════════════════════════════════════════════
function Test-StrategyViaTempBat {
    param(
        [string]$StrategyLine,
        [string[]]$Domains,
        [hashtable]$Baseline  = $null,   # url -> $true/$false (открыт без winws)
        [int]$WarmupSec       = $Global:ZapretState.WarmupSec,
        [string]$DebugDir     = ""
    )

    $winws = $Global:ZapretState.WinwsPath
    if (-not $winws -or -not (Test-Path $winws)) {
        Write-Log "winws.exe не найден" "ERR"
        return $null
    }
    $winwsDir = Split-Path $winws -Parent
    $procName = Get-ProcName

    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 400

    # ─── Временный .bat в CP866 ───
    $tempBat = Join-Path $env:TEMP ("winws_chk_" + [guid]::NewGuid().ToString('N') + ".bat")
    $batContent =
        "@echo off`r`n" +
        "cd /d `"$winwsDir`"`r`n" +
        "`"$winws`" $StrategyLine`r`n"
    try {
        [System.IO.File]::WriteAllText($tempBat, $batContent, [System.Text.Encoding]::GetEncoding(866))
    } catch {
        Write-Log "Не удалось создать временный .bat: $_" "ERR"
        return $null
    }

    if ($DebugDir -and (Test-Path $DebugDir)) {
        $dbg = Join-Path $DebugDir ("check_strategy_cmd_" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".bat")
        try { Copy-Item $tempBat $dbg -Force } catch { }
    }

    $proc = $null
    try {
        $proc = Start-Process -FilePath 'cmd.exe' `
                              -ArgumentList ('/c "' + $tempBat + '"') `
                              -WorkingDirectory $winwsDir `
                              -PassThru -WindowStyle Hidden
    } catch {
        Write-Log "Ошибка запуска cmd: $_" "ERR"
        Remove-Item $tempBat -Force -ErrorAction SilentlyContinue
        return $null
    }

    Start-Sleep -Milliseconds 1500

    $winwsProc = Get-Process $procName -ErrorAction SilentlyContinue
    if (-not $winwsProc) {
        $cmdCode = "?"
        try { $cmdCode = $proc.ExitCode } catch { }

        Write-Host ""
        Write-Host ("        [!] winws не запустился. Код cmd: {0}" -f $cmdCode) -ForegroundColor DarkRed
        if ($DebugDir) {
            Write-Host ("        Диагностический .bat: {0}" -f $DebugDir) -ForegroundColor DarkGray
        }

        Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
        Remove-Item $tempBat -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Strategy = $StrategyLine
            Score    = 0; Total = $Domains.Count; Details = @()
            New = 0; Kept = 0; Lost = 0; Still = 0
            Skipped  = $true
            SkipMsg  = "winws не запустился (cmd code=$cmdCode)"
        }
    }

    Start-Sleep -Seconds ([Math]::Max(0, $WarmupSec - 1))

    # ─── Прогон доменов через браузеро-подобный тест ───
    $results = @()
    foreach ($d in $Domains) {
        $r = Test-EndpointLikeBrowser -Url $d

        # Классификация относительно baseline
        if ($Baseline -and $Baseline.ContainsKey($d)) {
            $wasOpen = [bool]$Baseline[$d]
            $r | Add-Member -NotePropertyName WasOpen -NotePropertyValue $wasOpen -Force

            if     ($wasOpen -and $r.Ok)           { $status = "KEPT"  }
            elseif (-not $wasOpen -and $r.Ok)      { $status = "NEW"   }
            elseif ($wasOpen -and -not $r.Ok)      { $status = "LOST"  }
            else                                    { $status = "STILL" }
            $r | Add-Member -NotePropertyName Status -NotePropertyValue $status -Force
        } else {
            $r | Add-Member -NotePropertyName WasOpen -NotePropertyValue $null   -Force
            $r | Add-Member -NotePropertyName Status  -NotePropertyValue "UNK"    -Force
        }

        $results += $r
    }

    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    if ($proc -and -not $proc.HasExited) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch { }
    }
    Remove-Item $tempBat -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300

    $okTotal    = @($results | Where-Object Ok).Count
    $newCount   = @($results | Where-Object Status -eq "NEW").Count
    $keptCount  = @($results | Where-Object Status -eq "KEPT").Count
    $lostCount  = @($results | Where-Object Status -eq "LOST").Count
    $stillCount = @($results | Where-Object Status -eq "STILL").Count

    return [pscustomobject]@{
        Strategy = $StrategyLine
        Score    = $okTotal
        New      = $newCount
        Kept     = $keptCount
        Lost     = $lostCount
        Still    = $stillCount
        Total    = $results.Count
        Details  = $results
        Skipped  = $false
    }
}

# === ГЛАВНЫЙ ПРОГОН ===
function Invoke-CheckStrategy {
    param(
        [string[]]$Domains = $null,
        [int]$MaxDomains   = 0,
        [int]$ForceMode    = 0
    )

    if (-not (Test-Admin)) { Write-Log "Нужны права администратора" "ERR"; return }

    $clipText = Read-MultilineFromConsole
    if (-not $clipText -or $clipText.Trim() -eq '') {
        Write-Host "  [!] Пустой ввод. Ничего не вставлено." -ForegroundColor Yellow
        Read-Host "  Enter..."; return
    }

    Write-Host ""
    Write-Host ("  Получено {0} символов" -f $clipText.Length) -ForegroundColor Gray

    $mode = if ($ForceMode -in @(1,2)) { $ForceMode } else { Get-AutoMode -Text $clipText }
    if ($mode -notin @(1,2)) {
        Write-Host "  [!] Не удалось определить режим (нет ни winws.exe, ни --new)." -ForegroundColor Yellow
        Read-Host "  Enter..."; return
    }
    $modeLabel = if ($mode -eq 1) { "Режим 1 (bat с winws.exe)" } else { "Режим 2 (strategies.bat)" }
    Write-Host ("  Определён: {0}" -f $modeLabel) -ForegroundColor Cyan

    $strategies = @(Get-ClipStrategies -Text $clipText -ForceMode $mode)
    if ($strategies.Count -eq 0) {
        Write-Host "  [!] Стратегий не найдено." -ForegroundColor Yellow
        Read-Host "  Enter..."; return
    }

    Write-Log ("Стратегий: {0}" -f $strategies.Count) "INFO"
    Show-StrategyPreview -Strategies $strategies

    # ─── Диагностическая директория ───
    $usRoot = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
    $repDir = Join-Path $usRoot 'resultats'
    if (-not (Test-Path $repDir)) { New-Item -ItemType Directory -Path $repDir -Force | Out-Null }

    # Сохраняем раскрытые команды в отдельный файл
    $cmdFile = Join-Path $repDir 'check_strategy_cmd.txt'
    $sbCmd = New-Object System.Text.StringBuilder
    [void]$sbCmd.AppendLine("# Раскрытые команды winws (для отладки)")
    [void]$sbCmd.AppendLine("# Дата: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sbCmd.AppendLine("# Режим: $modeLabel")
    [void]$sbCmd.AppendLine("")
    $ci = 0
    foreach ($s in $strategies) {
        $ci++
        [void]$sbCmd.AppendLine(("# [{0}] length={1}" -f $ci, $s.Length))
        [void]$sbCmd.AppendLine($s.Line)
        [void]$sbCmd.AppendLine("")
    }
    Set-Content -Path $cmdFile -Value $sbCmd.ToString() -Encoding UTF8
    Write-Host ("  Раскрытые команды: {0}" -f $cmdFile) -ForegroundColor DarkGray

    if (-not $Domains -or $Domains.Count -eq 0) {
        $Domains = @(Get-DomainsFromHostlist -Max $MaxDomains)
    }
    if ($Domains.Count -eq 0) { Write-Log "Нет доменов" "ERR"; Read-Host "Enter..."; return }

    Write-Host ""
    Write-Host ("  Доменов:   {0}" -f $Domains.Count) -ForegroundColor Gray
    Write-Host ("  Стратегий: {0}" -f $strategies.Count) -ForegroundColor Gray
    Write-Host ""

    # ─── Полный baseline через браузеро-подобный тест ───
    $procName = Get-ProcName
    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500

    Write-Host "  Baseline (без winws, браузеро-подобно)..." -ForegroundColor DarkCyan
    $baseline = @{}
    $baselineOk = 0
    $bi = 0
    foreach ($d in $Domains) {
        $bi++
        $r = Test-EndpointLikeBrowser -Url $d -TimeoutSec 4
        $baseline[$d] = $r.Ok
        if ($r.Ok) { $baselineOk++ }

        $name = $d -replace '^https?://',''
        if ($r.Ok) {
            Write-Host ("    [{0,3}/{1}] [+] {2,-42} {3}" -f $bi, $Domains.Count, $name, $r.Msg) -ForegroundColor DarkGreen
        } else {
            Write-Host ("    [{0,3}/{1}] [-] {2,-42} {3}" -f $bi, $Domains.Count, $name, "blocked") -ForegroundColor DarkRed
        }
    }
    Write-Host ("  Baseline: {0}/{1} открыто без обхода" -f $baselineOk, $Domains.Count) -ForegroundColor Yellow
    Write-Host ""

    # ─── Тест стратегий ───
    $results   = New-Object System.Collections.Generic.List[object]
    $startTime = Get-Date
    $i = 0
    foreach ($s in $strategies) {
        $i++
        Write-Host ""
        Write-Host ("  [{0}/{1}] Режим {2}, длина {3}" -f $i, $strategies.Count, $s.Mode, $s.Length) -ForegroundColor Cyan

        $r = Test-StrategyViaTempBat -StrategyLine $s.Line -Domains $Domains -Baseline $baseline -DebugDir $repDir
        if ($r) {
            $pct = if ($r.Total -gt 0) { [math]::Round($r.Score / $r.Total * 100, 1) } else { 0 }
            $col = if ($r.Total -gt 0 -and $r.Score -eq $r.Total) { "Green" } elseif ($pct -ge 75) { "Yellow" } else { "White" }

            Write-Host ("    Всего открыто: [{0}/{1}]  {2}%" -f $r.Score, $r.Total, $pct) -ForegroundColor $col
            Write-Host ("    NEW={0}  KEPT={1}  LOST={2}  STILL={3}" -f `
                $r.New, $r.Kept, $r.Lost, $r.Still) -ForegroundColor Cyan

            $newList   = @($r.Details | Where-Object Status -eq "NEW"   | ForEach-Object { $_.Url -replace '^https?://','' })
            $lostList  = @($r.Details | Where-Object Status -eq "LOST"  | ForEach-Object { $_.Url -replace '^https?://','' })
            $stillList = @($r.Details | Where-Object Status -eq "STILL" | ForEach-Object { $_.Url -replace '^https?://','' })

            if ($newList.Count -gt 0) {
                Write-Host ("    NEW (открылось):   {0}" -f (($newList | Select-Object -First 25) -join ', ')) -ForegroundColor DarkGreen
            }
            if ($lostList.Count -gt 0) {
                Write-Host ("    LOST (сломалось):  {0}" -f (($lostList | Select-Object -First 25) -join ', ')) -ForegroundColor Red
            }
            if ($stillList.Count -gt 0) {
                Write-Host ("    STILL (не открыто): {0}" -f (($stillList | Select-Object -First 25) -join ', ')) -ForegroundColor DarkYellow
            }

            $results.Add([pscustomobject]@{
                Index = $i; Mode = $s.Mode; Line = $s.Line
                Score = $r.Score; Total = $r.Total; Pct = $pct
                New = $r.New; Kept = $r.Kept; Lost = $r.Lost; Still = $r.Still
                Details = $r.Details
            }) | Out-Null
        } else {
            Write-Host "    [!] Не удалось запустить winws" -ForegroundColor Red
        }
    }

    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force

    # ─── Итоги ───
    $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    Write-Host ""
    Write-Host "  ==============================================================" -ForegroundColor Cyan
    Write-Host "                     ИТОГИ ПРОВЕРКИ" -ForegroundColor Cyan
    Write-Host "  ==============================================================" -ForegroundColor Cyan
    Write-Host ("  Режим:    {0}" -f $modeLabel) -ForegroundColor Gray
    Write-Host ("  Время:    {0} мин" -f $totalTime) -ForegroundColor Gray
    Write-Host ("  Baseline: {0}/{1} открыто без обхода" -f $baselineOk, $Domains.Count) -ForegroundColor Yellow
    Write-Host ""
    foreach ($r in $results) {
        $col = if ($r.Total -gt 0 -and $r.Score -eq $r.Total) { "Green" } elseif ($r.Pct -ge 75) { "Yellow" } else { "White" }
        Write-Host ("  [{0,2}] все={1,2}/{2,2} ({3,5}%)  NEW={4,2} KEPT={5,2} LOST={6,2} STILL={7,2}" -f `
            $r.Index, $r.Score, $r.Total, $r.Pct, $r.New, $r.Kept, $r.Lost, $r.Still) -ForegroundColor $col
    }

    # ─── Отчёт ───
    $repFile = Join-Path $repDir 'check_strategy.txt'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# ===============================================================")
    [void]$sb.AppendLine("# CheckStrategy -- проверка стратегий из .bat (браузеро-подобно)")
    [void]$sb.AppendLine("# Дата: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# Режим: $modeLabel")
    [void]$sb.AppendLine("# Доменов: $($Domains.Count)")
    [void]$sb.AppendLine("# Baseline без обхода: $baselineOk/$($Domains.Count)")
    [void]$sb.AppendLine("# ===============================================================")
    [void]$sb.AppendLine("")

    foreach ($r in $results) {
        [void]$sb.AppendLine(("# [{0}] Mode={1}  Score = {2}/{3}  ({4}%)" -f $r.Index, $r.Mode, $r.Score, $r.Total, $r.Pct))
        [void]$sb.AppendLine(("# NEW={0}  KEPT={1}  LOST={2}  STILL={3}" -f $r.New, $r.Kept, $r.Lost, $r.Still))

        $newList   = @($r.Details | Where-Object Status -eq "NEW"    | ForEach-Object { $_.Url -replace '^https?://','' })
        $keptList  = @($r.Details | Where-Object Status -eq "KEPT"   | ForEach-Object { $_.Url -replace '^https?://','' })
        $lostList  = @($r.Details | Where-Object Status -eq "LOST"   | ForEach-Object { $_.Url -replace '^https?://','' })
        $stillList = @($r.Details | Where-Object Status -eq "STILL"  | ForEach-Object { $_.Url -replace '^https?://','' })

        if ($newList.Count   -gt 0) { [void]$sb.AppendLine("# NEW:   " + (($newList   | Select-Object -First 50) -join ', ')) }
        if ($keptList.Count  -gt 0) { [void]$sb.AppendLine("# KEPT:  " + (($keptList  | Select-Object -First 30) -join ', ')) }
        if ($lostList.Count  -gt 0) { [void]$sb.AppendLine("# LOST:  " + (($lostList  | Select-Object -First 50) -join ', ')) }
        if ($stillList.Count -gt 0) { [void]$sb.AppendLine("# STILL: " + (($stillList | Select-Object -First 50) -join ', ')) }

        [void]$sb.AppendLine("# Команда:")
        [void]$sb.AppendLine($r.Line)
        [void]$sb.AppendLine("")
    }
    Set-Content -Path $repFile -Value $sb.ToString() -Encoding UTF8

    Write-Host ""
    Write-Host ("  Отчёт:      {0}" -f $repFile) -ForegroundColor Green
    Write-Host ("  Команды:    {0}" -f $cmdFile) -ForegroundColor Green
    Write-Host ""
    Read-Host "  Enter..."
}

# === МЕНЮ ===
function Show-CheckStrategyMenu {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host "           ПРОВЕРКА СТРАТЕГИЙ ИЗ .BAT" -ForegroundColor Cyan
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Что делает:" -ForegroundColor DarkCyan
        Write-Host "    Проверяет стратегии из .bat: запускает winws.exe и смотрит," -ForegroundColor Gray
        Write-Host "    что открывается на доменах из hostlist." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Как пользоваться:" -ForegroundColor DarkCyan
        Write-Host "    1. Открой .bat в блокноте" -ForegroundColor Gray
        Write-Host "    2. Ctrl+A → Ctrl+C" -ForegroundColor Gray
        Write-Host "    3. Выбери пункт 1 ниже" -ForegroundColor Gray
        Write-Host "    4. Вставь в консоль (Ctrl+V / правая кнопка)" -ForegroundColor Gray
        Write-Host "    5. Enter, затем ещё раз Enter (пустая строка = конец)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Скрипт сам определит тип:" -ForegroundColor DarkCyan
        Write-Host "    Режим 1: полный .bat с winws.exe  →  1 стратегия" -ForegroundColor Gray
        Write-Host "    Режим 2: strategies.bat (--new)   →  N стратегий" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Проверка идёт как браузер:" -ForegroundColor DarkCyan
        Write-Host "    HTTP/2, HTTP/3 (QUIC), www-фолбэк, классификация" -ForegroundColor Gray
        Write-Host "    домена относительно baseline (NEW/KEPT/LOST/STILL)." -ForegroundColor Gray
        Write-Host ""
        Write-Host ("  BIN:   {0}" -f $(if ($Global:ZapretState.BinPath)   { $Global:ZapretState.BinPath   } else { "<не задан>" })) -ForegroundColor DarkGray
        Write-Host ("  LISTS: {0}" -f $(if ($Global:ZapretState.TxtPath)   { $Global:ZapretState.TxtPath   } else { "<не задан>" })) -ForegroundColor DarkGray
        Write-Host ("  winws: {0}" -f $(if ($Global:ZapretState.WinwsPath) { $Global:ZapretState.WinwsPath } else { "<не задан>" })) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "    1. ПРОВЕРИТЬ СТРАТЕГИИ (вставить из .bat)" -ForegroundColor Yellow
        Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "    0. Назад" -ForegroundColor DarkGray
        Write-Host ""

        $c = Read-Host "  Выбор"
        switch ($c) {
            "1" { Invoke-CheckStrategy -MaxDomains 0 }
            "0" { return }
            default {
                Write-Host "  [!] Неверный пункт" -ForegroundColor Yellow
                Start-Sleep -Milliseconds 700
            }
        }
    }
}