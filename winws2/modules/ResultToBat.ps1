# ===============================================================
# === RESULT → PRESET (ResultToBat.ps1) — winws2 ===
# ===============================================================
#  Собирает .txt-пресет в формате Generall_ALT1.txt из resultats\*.txt.
#  Использует ОТНОСИТЕЛЬНЫЕ пути (lua/, bin/fake/, lists/, windivert.filter/).
#  CWD пресета задаётся start.bat через `cd /d "%ROOT%"`.
# ===============================================================

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
                    Percent = if ($total -gt 0) { [math]::Round($score / $total * 100, 1) } else { 0 }
                    Method  = $method
                    Line    = $cmd
                }) | Out-Null
            }
            continue
        }

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
                    Percent = if ($curTotal -gt 0) { [math]::Round($curScore / $curTotal * 100, 1) } else { 0 }
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
#  Вырезать из строки только filter/payload/lua-desync
# ============================================================================
function Get-StrategyActionPart {
    param([string]$Line)
    if (-not $Line) { return "" }
    $pos = $Line.IndexOf('--filter-')
    if ($pos -lt 0) {
        $pos = $Line.IndexOf('--hostlist')
        if ($pos -lt 0) { $pos = $Line.IndexOf('--payload=') }
        if ($pos -lt 0) { return $Line }
    }
    return $Line.Substring($pos).Trim()
}

# ============================================================================
#  Абсолютные пути -> относительные (для формата Generall_ALT1)
# ============================================================================
function Convert-PathsToRelative {
    param([string]$Line)
    if (-not $Line) { return $Line }

    $r = $Line
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"]*?[\\/]windivert\.filter[\\/]', 'windivert.filter/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"]*?[\\/]bin[\\/]fake[\\/]',       'bin/fake/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"]*?[\\/]bin[\\/]',                'bin/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"]*?[\\/]lua[\\/]',                'lua/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"]*?[\\/]lists[\\/]',              'lists/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"]*?[\\/]runtime[\\/]',            'runtime/')
    return $r
}

# ============================================================================
#  Разбить строку стратегии на аргументы (с учётом кавычек)
# ============================================================================
function Split-Winws2Args {
    param([string]$Line)
    if (-not $Line) { return @() }

    $tokens  = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $inQuotes = $false

    foreach ($ch in $Line.ToCharArray()) {
        if ($ch -eq '"') {
            $inQuotes = -not $inQuotes
            [void]$current.Append($ch)
        } elseif (($ch -eq ' ' -or $ch -eq "`t") -and -not $inQuotes) {
            if ($current.Length -gt 0) {
                $tokens.Add($current.ToString())
                [void]$current.Clear()
            }
        } else {
            [void]$current.Append($ch)
        }
    }
    if ($current.Length -gt 0) { $tokens.Add($current.ToString()) }

    return @($tokens.ToArray())
}

# ============================================================================
#  Генерация .txt-пресета в формате Generall_ALT1.txt
# ============================================================================
function New-ComposedPreset {
    param(
        [object[]]$Strategies,
        [string]$OutputFile,
        [string]$Title = "COMPOSED",
        [string]$SourceInfo = ""
    )

    if (-not $Strategies -or $Strategies.Count -eq 0) {
        throw "Нет стратегий для сборки"
    }

    $sb = New-Object System.Text.StringBuilder

    # ── Заголовок ──
    [void]$sb.AppendLine('#=====================================================')
    [void]$sb.AppendLine('# блок 1 — ' + $Title)
    [void]$sb.AppendLine('# Автосгенерировано: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    [void]$sb.AppendLine('# Источник: ' + $SourceInfo)
    [void]$sb.AppendLine('# Стратегий: ' + $Strategies.Count)
    [void]$sb.AppendLine('#=====================================================')
    [void]$sb.AppendLine('')

    # ── Глобальная шапка (относительные пути) ──
    [void]$sb.AppendLine('--debug=0')
    [void]$sb.AppendLine('--ctrack-disable=0')
    [void]$sb.AppendLine('--ipcache-lifetime=8400')
    [void]$sb.AppendLine('--ipcache-hostname=1')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--lua-init=@"lua/zapret-lib.lua"')
    [void]$sb.AppendLine('--lua-init=@"lua/zapret-antidpi.lua"')
    [void]$sb.AppendLine('--lua-init=@"lua/zapret-auto.lua"')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--wf-tcp-out=80,443,2053,2083,2087,2096,8443,12')
    [void]$sb.AppendLine('--wf-udp-out=443,19294-19344,50000-50100,12')
    [void]$sb.AppendLine('--wf-raw-part=@"windivert.filter/windivert_part.discord_media.txt"')
    [void]$sb.AppendLine('--wf-raw-part=@"windivert.filter/windivert_part.stun.txt"')
    [void]$sb.AppendLine('--wf-raw-part=@"windivert.filter/windivert_part.wireguard.txt"')
    [void]$sb.AppendLine('--wf-raw-part=@"windivert.filter/windivert_part.quic_initial_ietf.txt"')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--blob=tls_google:@"bin/fake/tls_clienthello_www_google_com.bin"')
    [void]$sb.AppendLine('--blob=tls_max:@"bin/fake/tls_clienthello_max_ru.bin"')
    [void]$sb.AppendLine('--blob=quic_google:@"bin/fake/quic_initial_www_google_com.bin"')
    [void]$sb.AppendLine('--blob=stun:@"bin/fake/stun.bin"')
    [void]$sb.AppendLine('--blob=discord_voice:@"bin/fake/quic_initial_dbankcloud_ru.bin"')
    [void]$sb.AppendLine('--blob=game_udp:@"bin/fake/quic_initial_dbankcloud_ru.bin"')
    [void]$sb.AppendLine('--blob=http_iana:@"bin/fake/http_iana_org.bin"')
    [void]$sb.AppendLine('--blob=zero:@"bin/fake/zero_512.bin"')
    [void]$sb.AppendLine('')

    # ── Стратегии ──
    $idx = 0
    foreach ($s in $Strategies) {
        $idx++
        $actionRaw = Get-StrategyActionPart -Line $s.Line
        $actionRel = Convert-PathsToRelative -Line $actionRaw
        $tokens    = Split-Winws2Args -Line $actionRel

        [void]$sb.AppendLine('#========================================================')
        [void]$sb.AppendLine(('#  STRATEGY {0}  —  #{1}  [{2}/{3}]  {4}%' -f $idx, $s.Rank, $s.Score, $s.Total, $s.Percent))
        [void]$sb.AppendLine('#  ' + $s.Method)
        [void]$sb.AppendLine('#========================================================')

        foreach ($t in $tokens) {
            [void]$sb.AppendLine($t)
        }
        [void]$sb.AppendLine('--new')
        [void]$sb.AppendLine('')
    }

    $outPath = [IO.Path]::GetFullPath($OutputFile)
    $outDir  = Split-Path $outPath -Parent
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }
    [IO.File]::WriteAllText($outPath, $sb.ToString(), [Text.UTF8Encoding]::new($false))

    return [pscustomobject]@{
        OutputFile    = $outPath
        StrategyCount = $Strategies.Count
    }
}

# ============================================================================
#  Обёртка
# ============================================================================
function Invoke-ResultToPreset {
    param(
        [string]$SourceFile,
        [string]$OutputFile,
        [int]$TopN = 0
    )

    if (-not $SourceFile -or -not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
        Write-Log "Файл не найден: $SourceFile" "ERR"; return $null
    }

    if (-not $OutputFile) {
        $root  = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $OutputFile = Join-Path $root "presets\composed-$stamp.txt"
    }

    Write-Host ("  Читаю: {0}" -f $SourceFile) -ForegroundColor Cyan
    $strategies = @(Get-StrategiesFromFile -Path $SourceFile)
    if ($strategies.Count -eq 0) {
        Write-Log "Стратегии не найдены" "WARN"; return $null
    }

    Write-Host ("  Найдено: {0}" -f $strategies.Count) -ForegroundColor Gray
    if ($TopN -gt 0 -and $strategies.Count -gt $TopN) {
        $strategies = @($strategies | Select-Object -First $TopN)
        Write-Host ("  Ограничено TopN: {0}" -f $TopN) -ForegroundColor Gray
    }

    $result = New-ComposedPreset `
        -Strategies $strategies `
        -OutputFile $OutputFile `
        -Title ("COMPOSED from " + (Split-Path $SourceFile -Leaf)) `
        -SourceInfo $SourceFile

    Write-Log ("Собран пресет: {0} стратегий" -f $result.StrategyCount) "INFO"
    Write-Host ("  Файл: {0}" -f $result.OutputFile) -ForegroundColor Green
    return $result
}

# ============================================================================
#  Меню
# ============================================================================
function Show-ResultToPresetMenu {
    $root      = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
    $resultDir = Join-Path $root 'resultats'

    while ($true) {
        Clear-Host
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host "       RESULT → PRESET (формат Generall_ALT1, относит. пути)  " -ForegroundColor Cyan
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

        Write-Host "   1. Из resultat.txt  → presets\composed-<stamp>.txt" -ForegroundColor Green
        Write-Host "   2. Из pretest.txt   → presets\composed-<stamp>.txt" -ForegroundColor Yellow
        Write-Host "   3. Из verify.txt    → presets\composed-<stamp>.txt"
        Write-Host "   4. Указать .txt вручную"
        Write-Host "   5. Собрать из resultat.txt + pretest.txt"
        Write-Host ""
        Write-Host "   0. Назад" -ForegroundColor DarkGray
        Write-Host ""
        $c = Read-Host "Номер"

        $srcFile  = $null
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
        Write-Host "  Куда сохранить .txt?" -ForegroundColor Cyan
        Write-Host "    [Enter] = presets\composed-<timestamp>.txt" -ForegroundColor DarkGray
        $outFile = (Read-Host "  Путь").Trim('"').Trim("'")
        if (-not $outFile) {
            $stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
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

            $result = New-ComposedPreset `
                -Strategies $stratArr `
                -OutputFile $outFile `
                -Title ("COMPOSED from " + $sourceLabel) `
                -SourceInfo $sourceLabel

            Write-Host ""
            Write-Host ("  [OK] Собрано {0} стратегий" -f $result.StrategyCount) -ForegroundColor Green
            Write-Host ("  Файл: {0}" -f $result.OutputFile) -ForegroundColor Green
            Write-Host ""
            Write-Host "  Дальше:" -ForegroundColor DarkCyan
            Write-Host ("    • start.bat → выбрать '{0}' (файл в presets\)" -f [IO.Path]::GetFileNameWithoutExtension($result.OutputFile)) -ForegroundColor White
            Write-Host ("    • service.bat → пункт 1, выбрать '{0}'" -f [IO.Path]::GetFileNameWithoutExtension($result.OutputFile)) -ForegroundColor White
            Write-Host ""
            Read-Host "Enter..."
        } catch {
            Write-Log ("Ошибка сборки: {0}" -f $_.Exception.Message) "ERR"
            Read-Host "Enter..."
        }
    }
}