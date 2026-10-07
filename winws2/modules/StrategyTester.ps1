# ===============================================================
# === STRATEGY TESTER (StrategyTester.ps1) — winws2 / zapret2 ===
# ===============================================================
#  Пре-тест + полный прогон, авто-поиск заблокированных, RandomCount,
#  PreTestAllDomains — режим теста по ВСЕМ доменам hostlist.
#
#  Работает ТОЛЬКО с zapret2 (winws2.exe + Lua).
#
#  Поиск:
#    # === GET-HTTPTOOL ===            определить curl/wget
#    # === SHOW-HTTPTOOLSTATUS ===     показать доступные
#    # === TEST-ENDPOINT ===           проверить один URL
#    # === TEST-STRATEGY ===           проверить одну стратегию
#    # === GET-DOMAINSFROMHOSTLIST === читать домены из list-*.txt
#    # === INITIALIZE-RESULTFILE ===   создать файлы результата
#    # === ADD-STRATEGYTORESULT ===    дописать в resultat.txt
#    # === ADD-STRATEGYTOPRETEST ===   дописать в pretest.txt
#    # === SHOW-LIVECOUNTER ===        показать счётчик
#    # === INVOKE-STRATEGYSCAN ===     главный авто-тест (winws2)
#    # === TEST-SINGLESITE ===         пункт 15
#    # === TEST-CURRENTCONNECTION ===  пункт 16
#    # === SET-HTTPTOOL ===            пункт 17
#    # === EDIT-TESTDOMAINS ===        пункт 18
#    # === SHOW-RESULTFILE ===         пункт 14
#    # === SHOW-TESTSETTINGS ===       пункт 22
# ===============================================================

# ═════════════════════════════════════════════════════════════
#  HTTP
# ═════════════════════════════════════════════════════════════

function Get-HttpTool {
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    $wget = Get-Command wget.exe -ErrorAction SilentlyContinue
    [pscustomobject]@{
        curl = if ($curl) { $curl.Source } else { $null }
        wget = if ($wget) { $wget.Source } else { $null }
    }
}

function Show-HttpToolStatus {
    $t = Get-HttpTool
    Write-Host "  HTTP: " -ForegroundColor DarkCyan -NoNewline
    if ($t.curl) { Write-Host "curl OK " -ForegroundColor Green -NoNewline }
    if ($t.wget) { Write-Host "wget OK " -ForegroundColor Green -NoNewline }
    Write-Host "iwr OK" -ForegroundColor Green
    Write-Host "  Tool: $($Global:ZapretState.Tool)" -ForegroundColor DarkGray
}

function Test-Endpoint {
    param(
        [string]$Url,
        [int]$TimeoutSec = $Global:ZapretState.TimeoutSec,
        [string]$Tool = $Global:ZapretState.Tool
    )
    $r = [pscustomobject]@{ Url=$Url; Ok=$false; Tool=""; Msg=""; TimeMs=0 }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $tools = Get-HttpTool

    if (($Tool -eq "curl" -or $Tool -eq "auto") -and $tools.curl) {
        $r.Tool = "curl"
        $out = & $tools.curl -s -o NUL -w "%{http_code}" --max-time $TimeoutSec $Url 2>&1
        $code = "$out".Trim()
        if ($code -match '^\d{3}$' -and $code -ne '000') { $r.Ok = $true }
        $r.Msg = "HTTP $code"
    }
    elseif (($Tool -eq "wget" -or $Tool -eq "auto") -and $tools.wget) {
        $r.Tool = "wget"
        & $tools.wget --no-check-certificate -q -O NUL --timeout=$TimeoutSec $Url 2>$null
        $r.Ok = ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 8)
        $r.Msg = "exit $LASTEXITCODE"
    }
    else {
        $r.Tool = "iwr"
        try {
            $resp = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
            $r.Ok = $true
            $r.Msg = "HTTP $($resp.StatusCode)"
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response) {
                $r.Ok = $true
                $r.Msg = "HTTP $([int]$_.Exception.Response.StatusCode)"
            } else { $r.Ok = $false; $r.Msg = "conn fail" }
        }
        catch { $r.Msg = "err" }
    }

    $sw.Stop()
    $r.TimeMs = $sw.ElapsedMilliseconds
    return $r
}

# ═════════════════════════════════════════════════════════════
#  Разворачивание %LISTS% / %BIN% / %LUA%
# ═════════════════════════════════════════════════════════════

function Expand-BatVariables {
    param([string]$Line)

    if (-not $Line) { return $Line }

    $listsPath = [string]$Global:ZapretState.TxtPath
    $binPath   = [string]$Global:ZapretState.BinPath
    if ($listsPath) { $listsPath = ($listsPath -replace '\\','/').TrimEnd('/') + '/' }
    if ($binPath)   { $binPath   = ($binPath   -replace '\\','/').TrimEnd('/') + '/' }

    $luaPath = ""
    if ($Global:ZapretState.LuaLibPath) {
        $luaPath = Split-Path $Global:ZapretState.LuaLibPath -Parent
        $luaPath = ($luaPath -replace '\\','/').TrimEnd('/')
    }

    $Line = $Line.Replace('%LISTS%', $listsPath)
    $Line = $Line.Replace('%BIN%',   $binPath)
    $Line = $Line.Replace('%LUA%',   $luaPath)

    return $Line
}

# ═════════════════════════════════════════════════════════════
#  Тест стратегии (winws2)
# ═════════════════════════════════════════════════════════════

function Test-Strategy {
    param(
        [string]$StrategyLine,
        [string[]]$Domains,
        [int]$WarmupSec = $Global:ZapretState.WarmupSec,
        [switch]$Quiet
    )

    $StrategyLine = Expand-BatVariables -Line $StrategyLine

    if ($StrategyLine -match '%[A-Za-z_][A-Za-z0-9_]*%') {
        $vars = ([regex]::Matches($StrategyLine, '%[A-Za-z_][A-Za-z0-9_]*%') |
                 ForEach-Object { $_.Value } | Select-Object -Unique -First 5) -join ', '
        if (-not $Quiet) {
            Write-Host ("        [SKIP] Неразвёрнутые bat-переменные: {0}" -f $vars) -ForegroundColor DarkRed
        }
        return [pscustomobject]@{
            Strategy = $StrategyLine
            Score    = 0
            Total    = $Domains.Count
            Details  = @()
        }
    }

    $winws = $Global:ZapretState.Winws2Path
    if (-not $winws -or -not (Test-Path $winws)) {
        Write-Log "winws2.exe не найден" "ERR"; return $null
    }
    $winwsDir = Split-Path $winws -Parent

    $procName = Get-ProcName
    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 300

    $proc = $null
    try {
        $logOut = Join-Path $env:TEMP 'winws2_test.out.log'
        $logErr = Join-Path $env:TEMP 'winws2_test.err.log'
        Remove-Item $logOut, $logErr -ErrorAction SilentlyContinue

        $proc = Start-Process -FilePath $winws `
                            -ArgumentList $StrategyLine `
                            -WorkingDirectory $winwsDir `
                            -PassThru `
                            -RedirectStandardOutput $logOut `
                            -RedirectStandardError  $logErr `
                            -WindowStyle Hidden
    } catch { return $null }

    Start-Sleep -Milliseconds 700

    $exited = $true
    try { $exited = $proc.HasExited } catch { $exited = $true }

    if ($exited) {
        $code = "?"
        try { $code = $proc.ExitCode } catch { }
        if (-not $Quiet) {
            Write-Host ("        [SKIP] winws2 упал, код {0}" -f $code) -ForegroundColor DarkRed
            Write-Host ("        Строка: {0}" -f $StrategyLine.Substring(0, [Math]::Min(120, $StrategyLine.Length))) -ForegroundColor DarkGray
        }
        if (Test-Path $logErr) {
            $err = Get-Content $logErr -ErrorAction SilentlyContinue | Select-Object -Last 5
            foreach ($e in $err) { Write-Host ("        [stderr] {0}" -f $e) -ForegroundColor DarkRed }
        }
        if (Test-Path $logOut) {
            $out = Get-Content $logOut -ErrorAction SilentlyContinue | Select-Object -Last 10
            foreach ($o in $out) { Write-Host ("        [stdout] {0}" -f $o) -ForegroundColor DarkYellow }
        }

        Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
        return [pscustomobject]@{ Strategy=$StrategyLine; Score=0; Total=$Domains.Count; Details=@() }
    }

    if (-not $Quiet) {
        Write-Host ("        Прогрев {0} сек..." -f $WarmupSec) -ForegroundColor DarkGray
    }
    Start-Sleep -Seconds ([Math]::Max(0, $WarmupSec - 1))

    $results = @()
    $di = 0
    foreach ($d in $Domains) {
        $di++
        $r = Test-Endpoint -Url $d
        $results += $r

        if (-not $Quiet) {
            $name = $d -replace '^https?://',''
            Write-Host ("        [{0,3}/{1}] " -f $di, $Domains.Count) -ForegroundColor DarkGray -NoNewline

            if ($r.Ok) { $mCol="Green"; $uCol="White"; $mark="[+]" }
            else       { $mCol="Red";   $uCol="Red";   $mark="[-]" }

            Write-Host ("{0} " -f $mark) -ForegroundColor $mCol -NoNewline
            Write-Host ("{0,-45}" -f $name) -ForegroundColor $uCol -NoNewline
            Write-Host (" {0}" -f $r.Msg) -ForegroundColor $mCol
        }
        else {
            if ($di % 10 -eq 0) { Write-Host "." -NoNewline -ForegroundColor DarkGray }
        }
    }

    if ($Quiet) { Write-Host "" }

    if ($proc) {
        try {
            if (-not $proc.HasExited) {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        } catch { }
    }
    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 300

    $ok = @($results | Where-Object Ok).Count
    return [pscustomobject]@{
        Strategy = $StrategyLine
        Score    = $ok
        Total    = $results.Count
        Details  = $results
    }
}

#==============================================================================
# === RESOLVE-TXTPATH ===
# TxtPath может быть папкой ИЛИ конкретным .txt-файлом.
# Возвращает объект: Ok, IsFile, Directory, Files[], Err
#==============================================================================
function Resolve-TxtPath {
    param([string]$Path = $Global:ZapretState.TxtPath)

    $res = [pscustomobject]@{
        Ok = $false; IsFile = $false; Directory = ""; Files = @(); Err = ""
    }

    if (-not $Path) { $res.Err = "TxtPath не задан"; return $res }
    if (-not (Test-Path $Path)) { $res.Err = "Не найдено: $Path"; return $res }

    $item = Get-Item $Path

    if ($item.PSIsContainer) {
        $res.IsFile    = $false
        $res.Directory = $item.FullName
        $res.Files     = @(Get-ChildItem $item.FullName -Filter '*.txt' -File -ErrorAction SilentlyContinue |
                            Sort-Object Name | Select-Object -ExpandProperty FullName)
        if ($res.Files.Count -eq 0) { $res.Err = "В папке нет .txt: $($item.FullName)"; return $res }
        $res.Ok = $true
        return $res
    }

    if ($item.Extension.ToLower() -ne '.txt') {
        $res.Err = "Не .txt-файл: $($item.FullName)"
        return $res
    }

    $res.IsFile    = $true
    $res.Directory = $item.DirectoryName
    $res.Files     = @($item.FullName)
    $res.Ok = $true
    return $res
}

# ═════════════════════════════════════════════════════════════
#  Чтение доменов
# ═════════════════════════════════════════════════════════════

function Get-DomainsFromHostlist {
    param(
        [string]$TxtPath = $Global:ZapretState.TxtPath,
        [int]$Max = $Global:ZapretState.MaxDomains
    )

    $info = Resolve-TxtPath -Path $TxtPath
    if (-not $info.Ok) { Write-Log "TxtPath: $($info.Err)" "ERR"; return @() }

    $TxtDir = $info.Directory

    # ─── Список файлов для чтения ───
    if ($info.IsFile) {
        # Пользователь указал КОНКРЕТНЫЙ файл — читаем только его
        $hostFiles = @($info.Files)
        Write-Log "Hostlist: конкретный файл $(Split-Path $hostFiles[0] -Leaf)"
    }
    else {
        # Папка — стандартный набор кандидатов + все list-*.txt
        $list = New-Object System.Collections.Generic.List[string]
        $candidates = @(
            $Global:ZapretState.Hostlist,
            'list-general.txt',
            'list-general-user.txt',
            'list-google.txt',
            'list-google-user.txt'
        ) | Where-Object { $_ } | Select-Object -Unique

        foreach ($name in $candidates) {
            $f = Join-Path $TxtDir $name
            if (Test-Path $f) { $list.Add($f) }
        }

        # Дополнительно — все прочие list-*.txt, которых нет в списке кандидатов
        foreach ($f in (Get-ChildItem $TxtDir -Filter 'list-*.txt' -File -ErrorAction SilentlyContinue)) {
            if ($list -notcontains $f.FullName) { $list.Add($f.FullName) }
        }

        if ($list.Count -eq 0) {
            Write-Log "Не найден ни один hostlist в $TxtDir" "ERR"
            return @()
        }
        $hostFiles = @($list)
    }

    # ─── Исключения (только в режиме папки) ───
    $exclude = New-Object System.Collections.Generic.List[string]
    if (-not $info.IsFile) {
        foreach ($name in @($Global:ZapretState.HostlistExclude, 'list-exclude.txt', 'list-exclude-user.txt') | Select-Object -Unique) {
            $f = Join-Path $TxtDir $name
            if (Test-Path $f) {
                foreach ($line in (Get-Content $f -ErrorAction SilentlyContinue)) {
                    $e = $line.Trim().TrimStart('.').ToLower()
                    if ($e -and $e -notmatch '^#') { $exclude.Add($e) }
                }
            }
        }
    }

    # ─── Чтение доменов ───
    $domains = New-Object System.Collections.Generic.List[string]
    foreach ($hf in $hostFiles) {
        Write-Log "Читаю hostlist: $(Split-Path $hf -Leaf)"
        foreach ($line in (Get-Content $hf -ErrorAction SilentlyContinue)) {
            $l = $line.Trim()
            if (-not $l -or $l.StartsWith('#')) { continue }

            $d = $l -replace '^https?://','' -replace '^//','' -replace '^\.','' -replace '^\^',''
            $d = ($d -split '/')[0]; $d = ($d -split ':')[0]
            $d = $d.ToLower()

            if ($d -notmatch '^[a-z0-9]([a-z0-9\-\.]*[a-z0-9])?\.[a-z]{2,}$') { continue }

            $isExc = $false
            foreach ($e in $exclude) { if ($d -eq $e -or $d.EndsWith(".$e")) { $isExc=$true; break } }
            if ($isExc) { continue }
            if (-not $domains.Contains($d)) { $domains.Add($d) }
            if ($Max -gt 0 -and $domains.Count -ge $Max) { break }
        }
        if ($Max -gt 0 -and $domains.Count -ge $Max) { break }
    }

    $urls = @($domains | ForEach-Object { "https://$_" })
    Write-Log "Загружено доменов: $($urls.Count) (из $($hostFiles.Count) файлов)"
    return $urls
}

# ═════════════════════════════════════════════════════════════
#  Файлы результатов
# ═════════════════════════════════════════════════════════════

function Initialize-ResultFile {
    param(
        [string]$ResultFile,
        [string]$PretestFile,
        [int]$PreTestActual = 0
    )

    $dir = Split-Path $ResultFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if (Test-Path $ResultFile) {
        $bak = [System.IO.Path]::ChangeExtension($ResultFile, $null).TrimEnd('.') +
               "." + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".txt"
        Move-Item $ResultFile $bak -Force
        Write-Log "Старый результат сохранён: $bak"
    }

    $header = @"
# ═══════════════════════════════════════════════════════════════
# Zapret Manager 2 (winws2) — resultat.txt
# Начало: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# TargetScore: $($Global:ZapretState.TargetScore)
# MinScorePercent: $($Global:ZapretState.MinScorePercent)%
# TopN: $($Global:ZapretState.TopN)
# ═══════════════════════════════════════════════════════════════
# Файл обновляется в реальном времени.

:: НАЙДЕННЫЕ СТРАТЕГИИ (обновляется в реальном времени)
"@
    Set-Content -Path $ResultFile -Value $header -Encoding UTF8
    Write-Log "Инициализирован: $ResultFile"

    $need = [int]$Global:ZapretState.PreTestPassScore
    if ($need -le 0) { $need = "авто" }
    $total = if ($PreTestActual -gt 0) { $PreTestActual } else { "все" }

    $preHeader = @"
# ═══════════════════════════════════════════════════════════════
# Zapret Manager 2 (winws2) — pretest.txt
# Начало: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Критерий: Score >= $need из $total
# ═══════════════════════════════════════════════════════════════

"@
    Set-Content -Path $PretestFile -Value $preHeader -Encoding UTF8
}

function Add-StrategyToResult {
    param(
        [string]$ResultFile,
        [pscustomobject]$Result,
        [int]$Rank
    )

    if ($Result.Strategy -match '%[A-Za-z_][A-Za-z0-9_]*%') {
        $snip = $Result.Strategy.Substring(0, [Math]::Min(80, $Result.Strategy.Length))
        Write-Log ("Пропускаю результат с %VAR%: {0}" -f $snip) "WARN"
        return
    }

    $block = @"

# #$Rank  [$($Result.Score)/$($Result.Total)]  $($Result.Method)
--new
$($Result.Strategy)
"@
    Add-Content -Path $ResultFile -Value $block -Encoding UTF8
}

function Pluralize-RuSites {
    param([int]$N)
    $m10  = $N % 10
    $m100 = $N % 100
    if ($m10 -eq 1 -and $m100 -ne 11) { return 'сайт' }
    if ($m10 -ge 2 -and $m10 -le 4 -and ($m100 -lt 12 -or $m100 -gt 14)) { return 'сайта' }
    return 'сайтов'
}

function Add-StrategyToPretest {
    param(
        [string]$PretestFile,
        [pscustomobject]$Cand,
        [int]$PreScore,
        [int]$PreTotal,
        [int]$Index = 1,
        [string[]]$Worked = @(),
        [string[]]$Failed = @()
    )

    if ($Cand.Line -match '%[A-Za-z_][A-Za-z0-9_]*%') {
        $snip = $Cand.Line.Substring(0, [Math]::Min(80, $Cand.Line.Length))
        Write-Log ("Пропускаю в pretest.txt стратегию с %VAR%: {0}" -f $snip) "WARN"
        return
    }

    $okList    = if ($Worked.Count) { $Worked -join ', ' } else { '-' }
    $failList  = if ($Failed.Count) { $Failed -join ', ' } else { '-' }
    $okCount   = $Worked.Count
    $failCount = $Failed.Count
    $okWord    = Pluralize-RuSites $okCount
    $failWord  = Pluralize-RuSites $failCount

    $block = @"

# ═══════════════════════════════════════════════════════════════
# СТРАТЕГИЯ $Index  →  Score: $PreScore/$PreTotal
# ═══════════════════════════════════════════════════════════════
# OK   ($okCount $okWord):
#   $okList
# FAIL ($failCount $failWord):
#   $failList
--new
$($Cand.Line)
"@
    Add-Content -Path $PretestFile -Value $block -Encoding UTF8
}

function Show-LiveCounter {
    param([int]$Found, [int]$Checked, [int]$Total)
    Write-Host ("        [SAVE] Найдено: {0}  |  Проверено: {1}/{2}" -f $Found, $Checked, $Total) -ForegroundColor DarkGreen
}

# ═════════════════════════════════════════════════════════════
#  Основной прогон
# ═════════════════════════════════════════════════════════════

function Invoke-StrategyScan {
    param(
        [string[]]$Domains = $null,
        [string]$ResultFile = $Global:ZapretState.ResultFile,
        [int]$MaxDomains = $Global:ZapretState.MaxDomains
    )

    if (-not (Test-Admin)) { Write-Log "Нужны права администратора" "ERR"; return }

    if (-not $Domains) { $Domains = Get-DomainsFromHostlist -Max $MaxDomains }
    if ($Domains.Count -eq 0) { Write-Log "Нет доменов" "ERR"; return }

    # КОРРЕКЦИЯ: корректное определение абсолютного пути к resultats
    if (-not [System.IO.Path]::IsPathRooted($ResultFile)) {
        $root = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
        $ResultFile = [System.IO.Path]::GetFullPath((Join-Path $root $ResultFile))
    }
    $PretestFile = Join-Path (Split-Path $ResultFile -Parent) "pretest.txt"

    # КОРРЕКЦИЯ: сбрасываем счётчик для каждого прогона
    $global:FoundCount = 0

    $procName = Get-ProcName
    Write-Host ""
    Write-Host ("=== BASELINE (без {0}) ===" -f $procName) -ForegroundColor Magenta
    Write-Host "  Движок: zapret2 (winws2.exe + Lua)" -ForegroundColor DarkMagenta
    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500

    $baselineCheckCount = [int]$Global:ZapretState.BaselineCheckCount
    if ($baselineCheckCount -le 0) { $baselineCheckCount = 40 }
    $baselineCheckCount = [Math]::Min($baselineCheckCount, $Domains.Count)

    Write-Host ("  Проверяю {0} доменов из hostlist..." -f $baselineCheckCount) -ForegroundColor DarkGray
    Write-Host ""

    $baseline = @{}
    $blocked  = @()
    $baseOk   = 0
    $checked  = 0

    foreach ($d in $Domains) {
        if ($checked -ge $baselineCheckCount) { break }
        $checked++

        $r = Test-Endpoint -Url $d -TimeoutSec 3
        $baseline[$d] = $r.Ok
        $name = $d -replace '^https?://',''

        if ($r.Ok) {
            $baseOk++
            Write-Host ("  [+] {0,-45} {1}" -f $name, $r.Msg) -ForegroundColor DarkGreen
        } else {
            $blocked += $d
            Write-Host ("  [-] {0,-45} {1}  <- заблокирован" -f $name, $r.Msg) -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host ("  Baseline: {0}/{1} открыто без обхода" -f $baseOk, $checked) -ForegroundColor Yellow
    $blockedCol = if ($blocked.Count -gt 0) { "Cyan" } else { "Red" }
    Write-Host ("  Заблокированных найдено: {0}" -f $blocked.Count) -ForegroundColor $blockedCol

    $preCount   = [int]$Global:ZapretState.PreTestCount
    $preUrlsRaw = [string]$Global:ZapretState.PreTestUrls
    $preDomains = @()

    if ($preUrlsRaw -and $preUrlsRaw.Trim()) {
        $preDomains = @(
            $preUrlsRaw -split ',' | ForEach-Object {
                $u = $_.Trim()
                if (-not $u) { return }
                if ($u -notmatch '^https?://') { $u = "https://$u" }
                $u
            }
        )
        Write-Log "Пре-тест: PreTestUrls из settings.yml ($($preDomains.Count) шт.)"
    }
    elseif ($Global:ZapretState.PreTestAllDomains) {
        $preDomains = $Domains
        Write-Log "Пре-тест: ВСЕ домены из hostlist ($($preDomains.Count) шт.)" "INFO"
    }
    elseif ($blocked.Count -gt 0) {
        if ($preCount -le 0 -or $preCount -gt $blocked.Count) {
            $preDomains = $blocked
        } else {
            $preDomains = @($blocked | Select-Object -First $preCount)
        }
        Write-Log "Пре-тест: автоматически найдено заблокированных доменов: $($preDomains.Count)" "INFO"
    }
    else {
        Write-Log "Пре-тест: заблокированных доменов НЕ найдено!" "WARN"
        Write-Log "Все сайты в hostlist открываются без обхода." "WARN"
        return
    }

    if ($preDomains.Count -eq 0) {
        Write-Log "Пре-тест: нет сайтов — прерываю." "ERR"
        return
    }

    Initialize-ResultFile -ResultFile $ResultFile -PretestFile $PretestFile -PreTestActual $preDomains.Count

    # ─── Генерация стратегий (winws2 / Lua) ───
    Write-Log "Генерация Lua-стратегий для winws2..." "INFO"
    $candidates = @(New-Winws2StrategyCandidates)
    if ($candidates.Count -eq 0) {
        Write-Log "Нет кандидатов для тестирования." "ERR"
        return
    }

    Write-Host ""
    Write-Host ("=== ПРЕ-ТЕСТ ({0} кандидатов x {1} сайтов) ===" -f $candidates.Count, $preDomains.Count) -ForegroundColor Magenta
    Write-Host ""

    $passed = @()
    $preStart = Get-Date
    $pi = 0
    foreach ($c in $candidates) {
        $pi++
        $pct = [math]::Round($pi / $candidates.Count * 100, 0)
        Write-Host ("  [{0,3}/{1}] {2}%  " -f $pi, $candidates.Count, $pct) -ForegroundColor DarkMagenta -NoNewline
        Write-Host $c.Method -ForegroundColor White

        $r = Test-Strategy -StrategyLine $c.Line -Domains $preDomains -Quiet
        if ($r) {
            $worked = @($r.Details | Where-Object { $_.Ok }     | ForEach-Object { $_.Url -replace '^https?://','' })
            $failed = @($r.Details | Where-Object { -not $_.Ok } | ForEach-Object { $_.Url -replace '^https?://','' })

            foreach ($d in $r.Details) {
                $name = $d.Url -replace '^https?://',''
                if ($d.Ok) { Write-Host ("        [+] {0,-30} {1}" -f $name, $d.Msg) -ForegroundColor Green }
                else       { Write-Host ("        [-] {0,-30} {1}" -f $name, $d.Msg) -ForegroundColor DarkRed }
            }

            $needScore = [int]$Global:ZapretState.PreTestPassScore
            if ($needScore -le 0) { $needScore = [math]::Ceiling($r.Total / 2) }

            if ($r.Score -ge $needScore) {
                $passed += [pscustomobject]@{
                    Method    = $c.Method
                    Line      = $c.Line
                    PreScore  = $r.Score
                    PreTotal  = $r.Total
                }
                Write-Host ("        Пре-итог: {0}/{1}  прошёл" -f $r.Score, $r.Total) -ForegroundColor Green

                Add-StrategyToPretest -PretestFile $PretestFile -Cand $c `
                    -PreScore $r.Score -PreTotal $r.Total `
                    -Index $passed.Count `
                    -Worked $worked -Failed $failed

                $global:FoundCount++
                Show-LiveCounter -Found $global:FoundCount -Checked $pi -Total $candidates.Count
            } else {
                Write-Host ("        Пре-итог: {0}/{1}" -f $r.Score, $r.Total) -ForegroundColor DarkGray
            }
        }
    }
    $preTime = [math]::Round(((Get-Date) - $preStart).TotalMinutes, 1)
    Write-Host ""
    Write-Host ("=== ПРЕ-ТЕСТ ЗАВЕРШЁН за {0} мин: прошло {1} из {2} ===" -f $preTime, $passed.Count, $candidates.Count) -ForegroundColor Magenta

    if ($passed.Count -eq 0) {
        Write-Log "Ни одна стратегия не прошла пре-тест." "ERR"
        return
    }

    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Host ""
    Write-Host ("=== ПОЛНЫЙ ПРОГОН ({0} стратегий x {1} доменов) ===" -f $passed.Count, $Domains.Count) -ForegroundColor Magenta
    Write-Host ""

    $all = @()
    $startTime = Get-Date
    $targetHit = $false
    $i = 0

    foreach ($p in $passed) {
        $i++
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $eta = if ($i -gt 1) { [math]::Round(($elapsed/($i-1))*($passed.Count-$i+1)/60, 1) } else { "?" }
        Write-Host ("  [{0,3}/{1}] ETA {2} мин  " -f $i, $passed.Count, $eta) -ForegroundColor DarkMagenta -NoNewline
        Write-Host $p.Method -ForegroundColor White

        $r = Test-Strategy -StrategyLine $p.Line -Domains $Domains
        if ($r) {
            $r | Add-Member -NotePropertyName Method -NotePropertyValue $p.Method -Force
            $all += $r

            $col = if ($r.Score -eq $r.Total) { "Green" } elseif ($r.Score -ge $r.Total*0.75) { "Yellow" } else { "White" }
            Write-Host ("        Итог: {0}/{1}" -f $r.Score, $r.Total) -ForegroundColor $col

            $minPct = [double]$Global:ZapretState.MinScorePercent
            $passesFilter = ($r.Score -ge $Global:ZapretState.MinScore) -and
                            ($minPct -le 0 -or (($r.Score / $r.Total) * 100) -ge $minPct)
            if ($passesFilter) {
                $global:FoundCount++
                $rank = $global:FoundCount
                Add-StrategyToResult -ResultFile $ResultFile -Result $r -Rank $rank
                Write-Host ("        [SAVE] Сохранено [#{0}]" -f $rank) -ForegroundColor DarkGreen
            }

            $target = [int]$Global:ZapretState.TargetScore
            if ($target -gt 0 -and $r.Score -ge $target) {
                Write-Host ("  [OK] ДОСТИГНУТ TARGETSCORE={0}" -f $target) -ForegroundColor Green
                $targetHit = $true
                break
            }

            if ($i % 5 -eq 0) {
                try { $all | Export-Clixml -Path $Global:ZapretState.ProgressFile } catch { }
            }
        }
    }

    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)

    $allSorted = @($all | Where-Object {
        $_.Score -ge $Global:ZapretState.MinScore -and
        ([double]$Global:ZapretState.MinScorePercent -le 0 -or
         (($_.Score / $_.Total) * 100) -ge [double]$Global:ZapretState.MinScorePercent)
    } | Sort-Object -Property @{Expression='Score';Descending=$true})

    $topN = [int]$Global:ZapretState.TopN
    $finalList = if ($topN -gt 0 -and $allSorted.Count -gt $topN) {
        @($allSorted | Select-Object -First $topN)
    } else { $allSorted }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# ===============================================================")
    [void]$sb.AppendLine("# Zapret Manager 2 (winws2) - resultat.txt (ФИНАЛ)")
    [void]$sb.AppendLine("# Начало:   $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))")
    [void]$sb.AppendLine("# Конец:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# Baseline: $baseOk / $checked")
    [void]$sb.AppendLine("# Заблокировано: $($blocked.Count) доменов")
    [void]$sb.AppendLine("# Пре-тест: $($passed.Count) из $($candidates.Count)")
    [void]$sb.AppendLine("# Проверено: $($all.Count) за $totalTime мин")
    [void]$sb.AppendLine("# Итого: $($finalList.Count) лучших")
    [void]$sb.AppendLine("# ===============================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine(":: ЛУЧШИЕ СТРАТЕГИИ")
    [void]$sb.AppendLine("")

    $rank = 0
    foreach ($w in $finalList) {
        $rank++
        [void]$sb.AppendLine("# #$rank  [$($w.Score)/$($w.Total)]  $($w.Method)")
        [void]$sb.AppendLine("--new")
        [void]$sb.AppendLine($w.Strategy)
        [void]$sb.AppendLine("")
    }

    Set-Content -Path $ResultFile -Value $sb.ToString() -Encoding UTF8
    Write-Log "ФИНАЛ записан: $($finalList.Count) стратегий -> $ResultFile"

    $csvFile = [System.IO.Path]::ChangeExtension($ResultFile, '.csv')
    $all | Select-Object Method, Score, Total,
        @{N='Percent';E={[math]::Round($_.Score/$_.Total*100,1)}}, Strategy |
        Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Magenta
    Write-Host (" ТОП-20 (проверено: $($all.Count), время: $totalTime мин)") -ForegroundColor Magenta
    Write-Host ("=" * 80) -ForegroundColor Magenta
    $rank = 0
    foreach ($w in $finalList) {
        $rank++
        $col = if ($w.Score -eq $w.Total) { "Green" } elseif ($w.Score -ge $w.Total*0.75) { "Yellow" } else { "White" }
        Write-Host ("  #{0,2}  [{1,2}/{2}]  {3}" -f $rank, $w.Score, $w.Total, $w.Method) -ForegroundColor $col
    }
    Write-Host ("=" * 80) -ForegroundColor Magenta

    $Global:ZapretState.Strategies = @($finalList | ForEach-Object { $_.Strategy })
    Write-Log "Загружено в память: $($Global:ZapretState.Strategies.Count)"

    return $all
}

# ═════════════════════════════════════════════════════════════
#  Диагностика / меню
# ═════════════════════════════════════════════════════════════

function Test-SingleSite {
    $url = Read-Host "URL"
    if (-not $url) { return }
    $r = Test-Endpoint -Url $url
    $col = if ($r.Ok) { "Green" } else { "Red" }
    Write-Host ("  {0}  {1}  {2} ms" -f $r.Msg, $url, $r.TimeMs) -ForegroundColor $col
}

function Test-CurrentConnection {
    Write-Host ""
    $procName = Get-ProcName
    Write-Host ("  Проверка соединения без {0} [zapret2 (winws2.exe)]:" -f $procName) -ForegroundColor Magenta

    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500

    $urls = @(Get-DomainsFromHostlist -Max 15)
    $ok = 0
    foreach ($d in $urls) {
        $r = Test-Endpoint -Url $d
        if ($r.Ok) { $ok++; $col="Green" } else { $col="Red" }
        Write-Host ("    [{0}] {1,-45} {2}" -f $(if($r.Ok){"+"}else{"-"}), $d, $r.Msg) -ForegroundColor $col
    }
    Write-Host ("  Итог: {0}/{1}" -f $ok, $urls.Count) -ForegroundColor $(if($ok -eq $urls.Count){"Green"}elseif($ok -eq 0){"Red"}else{"Yellow"})
}

function Set-HttpTool {
    Write-Host "  1.auto  2.curl  3.wget  4.iwr"
    $c = Read-Host "Выбор"
    $Global:ZapretState.Tool = switch ($c) { "1"{"auto"} "2"{"curl"} "3"{"wget"} "4"{"iwr"} default {$Global:ZapretState.Tool} }
    Save-Settings
}

function Edit-TestDomains {
    $urls = @(Get-DomainsFromHostlist -Max 100)
    Write-Host "  Доменов: $($urls.Count):"
    $i=0; foreach ($u in $urls) { $i++; Write-Host ("    {0,3}. {1}" -f $i, $u) }
}

function Show-ResultFile {
    $file = $Global:ZapretState.ResultFile
    if (-not [System.IO.Path]::IsPathRooted($file)) {
        $file = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot -Parent) $file))
    }
    if (-not (Test-Path $file)) { Write-Log "Файл ещё не создан" "WARN"; return }
    Write-Host ("-" * 80) -ForegroundColor Magenta
    Get-Content $file | ForEach-Object {
        $line = $_
        if ($line -match '^#\s*#\d+') { Write-Host $line -ForegroundColor White }
        elseif ($line -match '^#') { Write-Host $line -ForegroundColor DarkGray }
        elseif ($line -match '^::') { Write-Host $line -ForegroundColor Magenta }
        elseif ($line -match '^--new') { Write-Host $line -ForegroundColor DarkMagenta }
        else { Write-Host $line -ForegroundColor White }
    }
    Write-Host ("-" * 80) -ForegroundColor Magenta
}

function Show-TestSettings {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================" -ForegroundColor Magenta
        Write-Host "         НАСТРОЙКИ winws2 (config/settings.yml)" -ForegroundColor Magenta
        Write-Host "==============================================================" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  --- Пути ----------------------------------------------" -ForegroundColor DarkGray
        Write-Host ("   1. winws2.exe   : {0}" -f $Global:ZapretState.Winws2Path)
        Write-Host ("   2. LuaLib       : {0}" -f $Global:ZapretState.LuaLibPath)
        Write-Host ("   3. LuaAntiDpi   : {0}" -f $Global:ZapretState.LuaAntiDpiPath)
        Write-Host ("   4. TxtPath      : {0}" -f $Global:ZapretState.TxtPath)
        Write-Host ("   5. BinPath      : {0}" -f $Global:ZapretState.BinPath)
        Write-Host ""
        Write-Host "  --- Тестирование --------------------------------------" -ForegroundColor DarkGray
        Write-Host ("   6. HTTP-tool    : {0}" -f $Global:ZapretState.Tool)
        Write-Host ("   7. WarmupSec    : {0}" -f $Global:ZapretState.WarmupSec)
        Write-Host ("   8. TimeoutSec   : {0}" -f $Global:ZapretState.TimeoutSec)
        Write-Host ("   9. MaxDomains   : {0}" -f $Global:ZapretState.MaxDomains)
        Write-Host ("  10. MinScore     : {0}" -f $Global:ZapretState.MinScore)
        Write-Host ("  11. TargetScore  : {0}" -f $Global:ZapretState.TargetScore)
        Write-Host ("  12. TopN         : {0}" -f $Global:ZapretState.TopN)
        Write-Host ("  13. MinScorePct  : {0} %" -f $Global:ZapretState.MinScorePercent)
        Write-Host ("  14. RandomCount  : {0}" -f $Global:ZapretState.RandomCount)
        Write-Host ""
        Write-Host "  --- Пре-тест ------------------------------------------" -ForegroundColor DarkGray
        Write-Host ("  15. PreTestCount : {0}" -f $Global:ZapretState.PreTestCount)
        Write-Host ("  16. PreTestPass  : {0}" -f $Global:ZapretState.PreTestPassScore)
        Write-Host ("  17. PreTestUrls  : {0}" -f $Global:ZapretState.PreTestUrls)
        Write-Host ("  18. BaselineChk  : {0}" -f $Global:ZapretState.BaselineCheckCount)
        Write-Host ("  19. PreTestAllDom: {0}  (True = все домены в пре-тест)" -f $Global:ZapretState.PreTestAllDomains)
        Write-Host ""
        Write-Host "  --- Файлы ---------------------------------------------" -ForegroundColor DarkGray
        Write-Host ("  20. ResultFile   : {0}" -f $Global:ZapretState.ResultFile)
        Write-Host ("  21. ProgressFile : {0}" -f $Global:ZapretState.ProgressFile)
        Write-Host ""
        Write-Host "  --- Lua-статус ----------------------------------------" -ForegroundColor DarkGray
        $luaCol = if ($Global:ZapretState.LuaReady) { "Green" } else { "Red" }
        Write-Host ("  Lua ready: {0}" -f $Global:ZapretState.LuaReady) -ForegroundColor $luaCol
        Write-Host ("  LuaMethods: {0}" -f $Global:ZapretState.LuaMethods.Count)
        Write-Host ("  LuaBlobs (builtin): {0}" -f $Global:ZapretState.LuaBlobs.Count)
        Write-Host ("  LuaBlobFiles (bin): {0}" -f $Global:ZapretState.LuaBlobFiles.Count)
        Write-Host ""
        Write-Host "   0. Назад" -ForegroundColor DarkGray
        Write-Host ""
        $c = Read-Host "Номер"
        switch ($c) {
            "1" { Set-Winws2Path }
            "2" { Set-LuaLibPath }
            "3" { Set-LuaAntiDpiPath }
            "4" { Set-TxtPath }
            "5" { Set-BinPath }
            "6" { Set-HttpTool }
            "7" { $Global:ZapretState.WarmupSec  = ConvertTo-Int (Read-Host "WarmupSec") $Global:ZapretState.WarmupSec; Save-Settings }
            "8" { $Global:ZapretState.TimeoutSec = ConvertTo-Int (Read-Host "TimeoutSec") $Global:ZapretState.TimeoutSec; Save-Settings }
            "9" { $Global:ZapretState.MaxDomains = ConvertTo-Int (Read-Host "MaxDomains (0=все)") $Global:ZapretState.MaxDomains; Save-Settings }
            "10" { $Global:ZapretState.MinScore   = ConvertTo-Int (Read-Host "MinScore") $Global:ZapretState.MinScore; Save-Settings }
            "11" { $Global:ZapretState.TargetScore = ConvertTo-Int (Read-Host "TargetScore (0=выкл)") $Global:ZapretState.TargetScore; Save-Settings }
            "12" { $Global:ZapretState.TopN      = ConvertTo-Int (Read-Host "TopN (0=все)") $Global:ZapretState.TopN; Save-Settings }
            "13" { $Global:ZapretState.MinScorePercent = ConvertTo-Int (Read-Host "MinScorePercent") $Global:ZapretState.MinScorePercent; Save-Settings }
            "14" { $Global:ZapretState.RandomCount  = ConvertTo-Int (Read-Host "RandomCount (0=полный перебор)") $Global:ZapretState.RandomCount; Save-Settings }
            "15" { $Global:ZapretState.PreTestCount     = ConvertTo-Int (Read-Host "PreTestCount (0=все)") $Global:ZapretState.PreTestCount; Save-Settings }
            "16" { $Global:ZapretState.PreTestPassScore = ConvertTo-Int (Read-Host "PreTestPassScore (0=авто)") $Global:ZapretState.PreTestPassScore; Save-Settings }
            "17" { $Global:ZapretState.PreTestUrls      = (Read-Host "PreTestUrls (через запятую)").Trim(); Save-Settings }
            "18" { $Global:ZapretState.BaselineCheckCount = ConvertTo-Int (Read-Host "BaselineCheckCount") $Global:ZapretState.BaselineCheckCount; Save-Settings }
            "19" { $Global:ZapretState.PreTestAllDomains = ConvertTo-Bool (Read-Host "PreTestAllDomains (True/False)") $Global:ZapretState.PreTestAllDomains; Save-Settings }
            "20" { $Global:ZapretState.ResultFile   = (Read-Host "ResultFile").Trim('"'); Save-Settings }
            "21" { $Global:ZapretState.ProgressFile = (Read-Host "ProgressFile").Trim('"'); Save-Settings }
            "0" { return }
        }
    }
}