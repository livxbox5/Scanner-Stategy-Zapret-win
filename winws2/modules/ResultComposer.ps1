# ===============================================================
# === RESULT COMPOSER (ResultComposer.ps1) — winws2 ===
# ===============================================================
#  Собирает стратегии из resultats\*.txt и формирует единый конфиг
#  в формате preprocess-config (set "VAR=..." + %VAR%).
#
#  Поиск:
#    # === GET-COMPOSERROOTPATHS ===        базовые пути для подстановки
#    # === CONVERT-PATHSTOPLACEHOLDERS ===   абсолютные пути → %VAR%
#    # === GET-STRATEGYBLOBS ===             вытащить --blob=name:@path
#    # === GET-STRATEGYACTIONPART ===        вырезать filter/payload/lua-desync
#    # === GET-STRATEGIESFROMFILE ===        парсит resultat/pretest/verify
#    # === NEW-COMPOSEDCONFIG ===            сформировать итоговый файл
#    # === INVOKE-RESULTCOMPOSER ===         главный сценарий
#    # === SHOW-RESULTCOMPOSERMENU ===       меню
# ===============================================================

# ============================================================================
#  ROOT-ПУТИ
# ============================================================================
function Get-ComposerRootPaths {
    $ws = $Global:ZapretState
    $root = $null

    if ($ws.Winws2Path) {
        $binDir = Split-Path $ws.Winws2Path -Parent
        if ($binDir) { $root = Split-Path $binDir -Parent }
    }
    if (-not $root -and $ws.ConfigFile) {
        $cfgDir = Split-Path $ws.ConfigFile -Parent
        if ($cfgDir) { $root = Split-Path $cfgDir -Parent }
    }
    if (-not $root) { $root = $PSScriptRoot }
    $root = $root.TrimEnd('\','/')

    $fwd = $root -replace '\\','/'

    $map = [ordered]@{}
    # ВАЖНО: длинные префиксы первыми
    $map["$fwd/windivert.filter/"] = '%WDF%/'
    $map["$fwd/bin/fake/"]         = '%FAKE%/'
    $map["$fwd/bin/"]              = '%BIN%/'
    $map["$fwd/lua/"]              = '%LUA%/'
    $map["$fwd/lists/"]            = '%LIST%/'
    $map["$fwd/runtime/"]          = '%RUNTIME%/'
    $map["$fwd/"]                  = '%ROOT%/'

    return [pscustomobject]@{ Root = $root; Map = $map }
}

function Convert-PathsToPlaceholders {
    param([string]$Line, [object]$PathMap)
    if (-not $Line -or -not $PathMap) { return $Line }
    $result = $Line
    foreach ($key in $PathMap.Map.Keys) {
        $bck = $key -replace '/','\'
        $result = $result.Replace($key, $PathMap.Map[$key])
        $result = $result.Replace($bck, $PathMap.Map[$key])
    }
    return $result
}

# ============================================================================
#  ИЗВЛЕЧЕНИЕ BLOB'ОВ И ACTION-ЧАСТИ
# ============================================================================
function Get-StrategyBlobs {
    param([string]$Line)
    $blobs = [ordered]@{}
    if (-not $Line) { return $blobs }
    foreach ($m in [regex]::Matches($Line, '--blob=([A-Za-z0-9_]+):@(?:"([^"]+)"|(\S+))')) {
        $name = $m.Groups[1].Value
        $path = if ($m.Groups[2].Success) { $m.Groups[2].Value } else { $m.Groups[3].Value }
        if (-not $blobs.Contains($name)) { $blobs[$name] = $path }
    }
    return $blobs
}

function Get-StrategyActionPart {
    param([string]$Line)
    if (-not $Line) { return "" }
    $pos = $Line.IndexOf('--filter-')
    if ($pos -lt 0) {
        # fallback — ищем первое вхождение --hostlist / --payload
        $pos = $Line.IndexOf('--hostlist')
        if ($pos -lt 0) { $pos = $Line.IndexOf('--payload=') }
        if ($pos -lt 0) { return $Line }
    }
    return $Line.Substring($pos).Trim()
}

# ============================================================================
#  ПАРСЕР resultats\*.txt
# ============================================================================
function Get-StrategiesFromFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }

    $raw   = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $lines = $raw -split "`r?`n"
    $items = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i].Trim()

        # ── resultat.txt / verify.txt: "# #N  [x/y]  method" ──
        if ($l -match '^#\s*#(\d+)\s*\[(\d+)/(\d+)\]\s*(.+)$') {
            $rank   = [int]$Matches[1]
            $score  = [int]$Matches[2]
            $total  = [int]$Matches[3]
            $method = $Matches[4].Trim()

            $cmd = ""
            for ($j = $i + 1; $j -lt $lines.Count -and $j -lt ($i + 15); $j++) {
                $c = $lines[$j].Trim()
                if ($c -eq '' -or $c -eq '--new' -or $c.StartsWith('#') -or $c.StartsWith('::')) { continue }
                $cmd = $c
                $i = $j
                break
            }
            if ($cmd) {
                $items.Add([pscustomobject]@{
                    Rank    = $rank
                    Score   = $score
                    Total   = $total
                    Percent = if ($total -gt 0) { [math]::Round($score/$total*100,1) } else { 0 }
                    Method  = $method
                    Line    = $cmd
                }) | Out-Null
            }
            continue
        }

        # ── pretest.txt: "# СТРАТЕГИЯ N → Score: x/y" ──
        if ($l -match '^#\s*.*?Score:\s*(\d+)/(\d+)\s*$') {
            $curScore = [int]$Matches[1]
            $curTotal = [int]$Matches[2]
            for ($j = $i + 1; $j -lt $lines.Count -and $j -lt ($i + 12); $j++) {
                $c = $lines[$j].Trim()
                if ($c -eq '--new') { continue }
                if ($c -eq '' -or $c.StartsWith('#') -or $c.StartsWith('::')) { continue }
                $items.Add([pscustomobject]@{
                    Rank    = $items.Count + 1
                    Score   = $curScore
                    Total   = $curTotal
                    Percent = if ($curTotal -gt 0) { [math]::Round($curScore/$curTotal*100,1) } else { 0 }
                    Method  = "(from pretest)"
                    Line    = $c
                }) | Out-Null
                $i = $j
                break
            }
            continue
        }
    }

    return @($items.ToArray())
}

# ============================================================================
#  СБОРКА КОНФИГА
# ============================================================================
function New-ComposedConfig {
    param(
        [object[]]$Strategies,
        [string]$OutputFile,
        [string]$Title = "COMPOSED",
        [string]$SourceInfo = ""
    )

    if (-not $Strategies -or $Strategies.Count -eq 0) {
        throw "Нет стратегий для составления"
    }

    $pathMap = Get-ComposerRootPaths
    $sb = New-Object System.Text.StringBuilder

    # ── Шапка ──
    [void]$sb.AppendLine("# ==============================================================")
    [void]$sb.AppendLine("# ZAPRET 2 NEXT — $Title")
    [void]$sb.AppendLine("# Автосгенерировано: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("# Источник: $SourceInfo")
    [void]$sb.AppendLine("# Стратегий: $($Strategies.Count)")
    [void]$sb.AppendLine("# ==============================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# Шапка — переменные (обрабатываются preprocess-config.ps1)")
    [void]$sb.AppendLine('set "BIN=%ROOT%/bin"')
    [void]$sb.AppendLine('set "FAKE=%BIN%/fake"')
    [void]$sb.AppendLine('set "LUA=%ROOT%/lua"')
    [void]$sb.AppendLine('set "WDF=%ROOT%/windivert.filter"')
    [void]$sb.AppendLine('set "LIST=%ROOT%/lists"')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('--chdir="%BIN%"')
    [void]$sb.AppendLine("--debug=0")
    [void]$sb.AppendLine("--ctrack-disable=0")
    [void]$sb.AppendLine("--ipcache-lifetime=8400")
    [void]$sb.AppendLine("--ipcache-hostname=1")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('--lua-init=@"%LUA%/zapret-lib.lua"')
    [void]$sb.AppendLine('--lua-init=@"%LUA%/zapret-antidpi.lua"')
    [void]$sb.AppendLine('--lua-init=@"%LUA%/zapret-auto.lua"')
    [void]$sb.AppendLine("")

    # ── Уникальные blob'ы из стратегий ──
    $allBlobs = [ordered]@{}
    foreach ($s in $Strategies) {
        $b = Get-StrategyBlobs -Line $s.Line
        foreach ($name in $b.Keys) {
            if (-not $allBlobs.Contains($name)) {
                $allBlobs[$name] = $b[$name]
            }
        }
    }

    # ── Стандартные fallback-blob'ы, если их нет ──
    $fallback = [ordered]@{
        'tls_google'    = '%FAKE%/tls_clienthello_www_google_com.bin'
        'tls_max'       = '%FAKE%/tls_clienthello_max_ru.bin'
        'quic_google'   = '%FAKE%/quic_initial_www_google_com.bin'
        'stun'          = '%FAKE%/stun.bin'
        'discord_voice' = '%FAKE%/quic_initial_dbankcloud_ru.bin'
        'game_udp'      = '%FAKE%/quic_initial_dbankcloud_ru.bin'
        'http_iana'     = '%FAKE%/http_iana_org.bin'
        'zero'          = '%FAKE%/zero_512.bin'
    }

    $emitted = New-Object System.Collections.Generic.HashSet[string]

    # Сначала — реально используемые
    foreach ($name in $allBlobs.Keys) {
        $path = Convert-PathsToPlaceholders -Line $allBlobs[$name] -PathMap $pathMap
        [void]$sb.AppendLine("--blob=$name`:@`"$path`"")
        [void]$emitted.Add($name)
    }
    # Потом — fallback (если ещё не добавлены)
    foreach ($name in $fallback.Keys) {
        if ($emitted.Contains($name)) { continue }
        [void]$sb.AppendLine("--blob=$name`:@`"$($fallback[$name])`"")
    }
    [void]$sb.AppendLine("")

    # ── Стратегии ──
    $idx = 0
    foreach ($s in $Strategies) {
        $idx++
        $actionLine = Get-StrategyActionPart -Line $s.Line
        $actionLine = Convert-PathsToPlaceholders -Line $actionLine -PathMap $pathMap

        [void]$sb.AppendLine("#========================================================")
        [void]$sb.AppendLine("#  STRATEGY $idx  —  #$($s.Rank)  [$($s.Score)/$($s.Total)]  $($s.Percent)%")
        [void]$sb.AppendLine("#  $($s.Method)")
        [void]$sb.AppendLine("#========================================================")
        [void]$sb.AppendLine($actionLine)
        [void]$sb.AppendLine("--new")
        [void]$sb.AppendLine("")
    }

    $outPath = [IO.Path]::GetFullPath($OutputFile)
    $outDir  = Split-Path $outPath -Parent
    if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
    [IO.File]::WriteAllText($outPath, $sb.ToString(), [Text.UTF8Encoding]::new($false))

    return [pscustomobject]@{
        OutputFile    = $outPath
        StrategyCount = $Strategies.Count
        BlobCount     = $emitted.Count
    }
}

function Invoke-ResultComposer {
    param(
        [string]$SourceFile,
        [string]$OutputFile,
        [int]$TopN = 0
    )

    if (-not $SourceFile -or -not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
        Write-Log "Файл не найден: $SourceFile" "ERR"; return $null
    }

    if (-not $OutputFile) {
        $root = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $OutputFile = Join-Path $root "presets\composed-$stamp.txt"
    }

    Write-Host ("  Читаю: {0}" -f $SourceFile) -ForegroundColor Cyan
    $strategies = @(Get-StrategiesFromFile -Path $SourceFile)
    if ($strategies.Count -eq 0) { Write-Log "Стратегии не найдены" "WARN"; return $null }

    Write-Host ("  Найдено: {0}" -f $strategies.Count) -ForegroundColor Gray
    if ($TopN -gt 0 -and $strategies.Count -gt $TopN) {
        $strategies = @($strategies | Select-Object -First $TopN)
        Write-Host ("  Ограничено TopN: {0}" -f $TopN) -ForegroundColor Gray
    }

    $result = New-ComposedConfig `
        -Strategies $strategies `
        -OutputFile $OutputFile `
        -Title "COMPOSED from $(Split-Path $SourceFile -Leaf)" `
        -SourceInfo $SourceFile

    Write-Log ("Конфиг собран: {0} стратегий, {1} blob'ов" -f $result.StrategyCount, $result.BlobCount) "INFO"
    Write-Host ("  Файл: {0}" -f $result.OutputFile) -ForegroundColor Green
    return $result
}

# ============================================================================
#  МЕНЮ
# ============================================================================
function Show-ResultComposerMenu {
    $root      = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
    $resultDir = Join-Path $root 'resultats'

    while ($true) {
        Clear-Host
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host "        RESULT COMPOSER — сборка конфига из resultats/        " -ForegroundColor Cyan
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host ("  Папка resultats/: {0}" -f $resultDir) -ForegroundColor DarkCyan
        Write-Host ""

        if (Test-Path -LiteralPath $resultDir -PathType Container) {
            $files = @(Get-ChildItem -LiteralPath $resultDir -Filter '*.txt' -File -ErrorAction SilentlyContinue | Sort-Object Name)
            if ($files.Count -gt 0) {
                foreach ($f in $files) {
                    $cnt = @(Get-StrategiesFromFile -Path $f.FullName).Count
                    Write-Host ("    {0,-32} ({1} стратегий)" -f $f.Name, $cnt)
                }
            } else {
                Write-Host "    <пусто>" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "    <папка не найдена>" -ForegroundColor Red
        }
        Write-Host ""

        Write-Host "   1. Собрать из resultat.txt (финал)" -ForegroundColor Green
        Write-Host "   2. Собрать из pretest.txt (черновик)" -ForegroundColor Yellow
        Write-Host "   3. Собрать из verify.txt"
        Write-Host "   4. Указать путь к .txt вручную"
        Write-Host "   5. Собрать ИЗ НЕСКОЛЬКИХ (resultat + pretest)"
        Write-Host ""
        Write-Host "   0. Назад" -ForegroundColor DarkGray
        Write-Host ""
        $c = Read-Host "Номер"

        $srcFile = $null
        $srcFiles = @()

        switch ($c) {
            "1" { $srcFile = Join-Path $resultDir 'resultat.txt' }
            "2" { $srcFile = Join-Path $resultDir 'pretest.txt' }
            "3" { $srcFile = Join-Path $resultDir 'verify.txt' }
            "4" { $srcFile = (Read-Host "Путь к .txt-файлу").Trim('"').Trim("'") }
            "5" {
                $srcFiles = @(
                    (Join-Path $resultDir 'resultat.txt'),
                    (Join-Path $resultDir 'pretest.txt')
                ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
                if ($srcFiles.Count -eq 0) {
                    Write-Log "Ни resultat.txt, ни pretest.txt не найдены" "WARN"
                    Read-Host "Enter..."; continue
                }
            }
            "0" { return }
            default { continue }
        }

        if ($srcFile -and -not (Test-Path -LiteralPath $srcFile -PathType Leaf)) {
            Write-Log "Файл не найден: $srcFile" "ERR"
            Read-Host "Enter..."; continue
        }

        Write-Host ""
        Write-Host "  Куда сохранить?" -ForegroundColor Cyan
        Write-Host "    [Enter] = автоматически в presets\composed-<timestamp>.txt"
        $outFile = (Read-Host "  Путь").Trim('"').Trim("'")
        if (-not $outFile) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $outFile = Join-Path $root "presets\composed-$stamp.txt"
        }

        Write-Host ""
        $topNStr = (Read-Host "  Ограничить TopN стратегий (Enter = все)").Trim()
        $topN = 0
        if ($topNStr) { [void][int]::TryParse($topNStr, [ref]$topN) }

        try {
            $allStrategies = New-Object System.Collections.Generic.List[object]
            $sourceLabel = ""
            if ($srcFiles.Count -gt 0) {
                foreach ($f in $srcFiles) {
                    $items = @(Get-StrategiesFromFile -Path $f)
                    Write-Host ("  Из {0}: {1} стратегий" -f (Split-Path $f -Leaf), $items.Count) -ForegroundColor Gray
                    foreach ($it in $items) { $allStrategies.Add($it) | Out-Null }
                }
                $sourceLabel = ($srcFiles | ForEach-Object { Split-Path $_ -Leaf }) -join ' + '
            } else {
                $items = @(Get-StrategiesFromFile -Path $srcFile)
                foreach ($it in $items) { $allStrategies.Add($it) | Out-Null }
                $sourceLabel = Split-Path $srcFile -Leaf
            }

            if ($allStrategies.Count -eq 0) {
                Write-Log "Стратегии не найдены" "WARN"
                Read-Host "Enter..."; continue
            }

            $stratArr = @($allStrategies.ToArray())
            if ($topN -gt 0 -and $stratArr.Count -gt $topN) {
                $stratArr = @($stratArr | Select-Object -First $topN)
            }

            $result = New-ComposedConfig `
                -Strategies $stratArr `
                -OutputFile $outFile `
                -Title "COMPOSED from $sourceLabel" `
                -SourceInfo $sourceLabel

            Write-Host ""
            Write-Host ("  [OK] Собрано {0} стратегий" -f $result.StrategyCount) -ForegroundColor Green
            Write-Host ("  Файл: {0}" -f $result.OutputFile) -ForegroundColor Green
            Write-Host ""
            Write-Host "  Запуск:" -ForegroundColor DarkCyan
            $nameOnly = [IO.Path]::GetFileNameWithoutExtension($result.OutputFile)
            Write-Host ("    start.bat {0}" -f $nameOnly) -ForegroundColor White
            Write-Host ""
            Read-Host "Enter..."
        } catch {
            Write-Log ("Ошибка сборки: {0}" -f $_.Exception.Message) "ERR"
            Read-Host "Enter..."
        }
    }
}