# ===============================================================
# === WEB INTEL (WebIntel.ps1) — поиск стратегий в интернете ===
# ===============================================================
#  Ищет упоминания рабочих стратегий для winws2/nfqws в:
#    - GitHub Issues (bol-van/zapret, bol-van/zapret2, Flowseal/...)
#    - ntc.party (форум)
#    - DuckDuckGo HTML (поиск)
#    - Произвольные URL (пользователь вставляет)
#
#  Извлекает паттерны:
#    --lua-desync=..., --filter-*, --blob=..., --wf-*, --hostlist=...
#    --dpi-desync=... (для zapret1 / nfqws)
#
#  Дедуплицирует и складывает в config/discovered.json.
#
#  ⚠️ ВАЖНО:
#    - Всё найденное СЧИТАЕТСЯ НЕПРОВЕРЕННЫМ.
#    - Перед запуском стратегия проходит Test-Strategy (winws2 сам
#      скажет, валидна ли она).
#    - Код из интернета НЕ выполняется. Только текст → regex → строка.
#    - Соблюдаем rate-limit GitHub API (10 поисковых запросов/мин).
#
#  Логирование HTTP:
#    $VerbosePreference = 'Continue'  → все запросы будут видны
# ===============================================================

$Global:WebIntelConfig = [ordered]@{
    GitHubRepos   = @(
        'bol-van/zapret',
        'bol-van/zapret2',
        'Flowseal/zapret-discord-youtube',
        'ValdikSS/GoodbyeDPI'
    )
    NtcPartyBase  = 'https://ntc.party'
    CacheHours    = 24
    UserAgent     = 'ZapretManager/2.0 (web-intel)'
    MaxResults    = 200
    GitHubPerPage = 30
    RequestDelay  = 1.5
}

# ═════════════════════════════════════════════════════════════
#  ПУТИ / ХРАНИЛИЩЕ
# ═════════════════════════════════════════════════════════════
function Get-WebIntelDbPath {
    $cfg = Split-Path $Global:ZapretState.ConfigFile -Parent
    return (Join-Path $cfg 'discovered.json')
}

function Get-WebIntelCachePath {
    $cfg = Split-Path $Global:ZapretState.ConfigFile -Parent
    $dir = Join-Path $cfg 'webintel-cache'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Load-WebIntelDb {
    $file = Get-WebIntelDbPath
    $empty = [pscustomobject]@{
        Version    = 1
        Updated    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Strategies = @()
    }
    if (-not (Test-Path $file)) { return $empty }
    try {
        $raw = Get-Content $file -Raw -Encoding UTF8
        if (-not $raw -or $raw.Trim() -eq '') { return $empty }
        $obj = $raw | ConvertFrom-Json
        if (-not $obj.PSObject.Properties['Strategies']) {
            $obj | Add-Member -NotePropertyName Strategies -NotePropertyValue @() -Force
        }
        return $obj
    } catch {
        Write-Log "Не удалось прочитать discovered.json: $_" "WARN"
        return $empty
    }
}

function Save-WebIntelDb {
    param($Db)
    $file = Get-WebIntelDbPath
    try {
        $Db.Updated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        $json = $Db | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($file, $json, [Text.UTF8Encoding]::new($false))
    } catch {
        Write-Log "Ошибка сохранения discovered.json: $_" "ERR"
    }
}

# ═════════════════════════════════════════════════════════════
#  ИЗВЛЕЧЕНИЕ ПАТТЕРНОВ
# ═════════════════════════════════════════════════════════════
function ConvertTo-RelativePaths {
    param([string]$Line)
    if (-not $Line) { return $Line }
    $r = $Line
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"\s]*?[\\/]lua[\\/]',           'lua/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"\s]*?[\\/]bin[\\/]fake[\\/]',   'bin/fake/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"\s]*?[\\/]bin[\\/]',            'bin/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"\s]*?[\\/]lists[\\/]',          'lists/')
    $r = [regex]::Replace($r, '(?i)[A-Z]:[\\/][^"\s]*?[\\/]windivert\.filter[\\/]', 'windivert.filter/')
    return $r
}

function Extract-StrategyPatterns {
    param(
        [string]$Text,
        [string]$Source = "unknown"
    )

    if (-not $Text -or $Text.Length -lt 20) { return @() }

    $found = New-Object System.Collections.Generic.List[object]
    $seen  = New-Object System.Collections.Generic.HashSet[string]

    $Text  = $Text -replace "`r`n", "`n" -replace "`r", "`n"
    $lines = $Text -split "`n"

    foreach ($line in $lines) {
        $l = $line.Trim()
        if ($l.Length -lt 20 -or $l.Length -gt 4000) { continue }
        if ($l -match '^\s*(#|//|<!--|::)') { continue }

        # Все аргументы вида --xxx=yyy или --flag
        $tokenMatches = [regex]::Matches($l, '(--[a-z0-9][a-z0-9-]*(?:=(?:"[^"]*"|[^\s`"]+))?)')
        if ($tokenMatches.Count -lt 2) { continue }

        $tokens = @($tokenMatches | ForEach-Object { $_.Value })

        $hasDesync = $false
        $hasFilter = $false
        $isWinws2  = $false
        $isNfqws   = $false

        foreach ($t in $tokens) {
            if ($t -match '^--lua-desync=|^--lua-init=')              { $isWinws2  = $true; $hasDesync = $true }
            if ($t -match '^--dpi-desync=|^--dpi-desync-')            { $isNfqws   = $true; $hasDesync = $true }
            if ($t -match '^--(filter-|wf-|hostlist|hostlist-exclude)') { $hasFilter = $true }
        }
        if (-not $hasDesync) { continue }

        # Собираем candidate строку
        $candidate = ($tokens -join ' ').Trim()
        $candidate = ConvertTo-RelativePaths -Line $candidate

        # Отбрасываем слишком короткие (типа одной lua-desync без контекста)
        if ($candidate.Length -lt 30) { continue }

        # Дедупликация
        $key = $candidate.ToLowerInvariant()
        if ($seen.Contains($key)) { continue }
        [void]$seen.Add($key)

        # Классификация "полноты"
        $completeness = 'fragment'
        if ($hasFilter -and $candidate -match '--lua-desync=') { $completeness = 'full-winws2' }
        elseif ($hasFilter -and $candidate -match '--dpi-desync=') { $completeness = 'full-nfqws' }
        elseif ($candidate -match '^--lua-desync=') { $completeness = 'winws2-fragment' }
        elseif ($candidate -match '^--dpi-desync=') { $completeness = 'nfqws-fragment' }

        $found.Add([pscustomobject]@{
            Candidate    = $candidate
            Source       = $Source
            Engine       = if ($isWinws2) { 'winws2' } elseif ($isNfqws) { 'nfqws' } else { 'unknown' }
            Completeness = $completeness
            Length       = $candidate.Length
            ExtractedAt  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }) | Out-Null

        if ($found.Count -ge 500) { break }
    }

    return @($found.ToArray())
}

# ═════════════════════════════════════════════════════════════
#  ДЕДУП И СЛИЯНИЕ С БАЗОЙ
# ═════════════════════════════════════════════════════════════
function Add-DiscoveredPatterns {
    param(
        [object[]]$Patterns,
        [string]$SourceTag = "web"
    )

    if (-not $Patterns -or $Patterns.Count -eq 0) { return 0 }

    $db = Load-WebIntelDb
    $existing = @($db.Strategies)
    $existingKeys = New-Object System.Collections.Generic.HashSet[string]
    foreach ($e in $existing) {
        if ($e.Candidate) { [void]$existingKeys.Add($e.Candidate.ToLowerInvariant()) }
    }

    $added = 0
    foreach ($p in $Patterns) {
        $key = $p.Candidate.ToLowerInvariant()
        if ($existingKeys.Contains($key)) {
            # Обновляем LastSeen у существующей
            foreach ($e in $existing) {
                if ($e.Candidate -and $e.Candidate.ToLowerInvariant() -eq $key) {
                    $e.LastSeen = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    $e.SeenCount = ([int]$e.SeenCount) + 1
                    break
                }
            }
            continue
        }

        $new = [pscustomobject]@{
            Candidate    = $p.Candidate
            Source       = $p.Source
            SourceTag    = $SourceTag
            Engine       = $p.Engine
            Completeness = $p.Completeness
            FirstSeen    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            LastSeen     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            SeenCount    = 1
            Tested       = $false
            TestScore    = 0
            TestTotal    = 0
        }
        $existing += $new
        [void]$existingKeys.Add($key)
        $added++
    }

    $db.Strategies = @($existing)
    Save-WebIntelDb -Db $db
    return $added
}

# ═════════════════════════════════════════════════════════════
#  HTTP-ХЕЛПЕР
# ═════════════════════════════════════════════════════════════
function Invoke-WebFetch {
    [CmdletBinding()]
    param(
        [string]$Url,
        [int]$TimeoutSec = 20,
        [hashtable]$Headers = @{},
        [switch]$ReturnJson
    )

    $defaultHeaders = @{
        'User-Agent' = $Global:WebIntelConfig.UserAgent
        'Accept'     = 'text/html,application/json,text/plain;q=0.9,*/*;q=0.5'
    }
    foreach ($k in $Headers.Keys) { $defaultHeaders[$k] = $Headers[$k] }

    Write-Verbose ("[HTTP] GET {0} (timeout={1}s, json={2})" -f $Url, $TimeoutSec, [bool]$ReturnJson)

    try {
        if ($ReturnJson) {
            $res = Invoke-RestMethod -Uri $Url -Headers $defaultHeaders `
                                     -TimeoutSec $TimeoutSec -ErrorAction Stop
            Write-Verbose ("[HTTP] OK {0}" -f $Url)
            return $res
        }
        $resp = Invoke-WebRequest -Uri $Url -Headers $defaultHeaders `
                                  -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
        Write-Verbose ("[HTTP] OK {0}  ({1} bytes)" -f $Url, $resp.Content.Length)
        return $resp.Content
    } catch {
        Write-Log ("HTTP fail [{0}]: {1}" -f $Url, $_.Exception.Message) "WARN"
        Write-Verbose ("[HTTP] FAIL {0}: {1}" -f $Url, $_.Exception.Message)
        return $null
    }
}

# ═════════════════════════════════════════════════════════════
#  GITHUB ISSUES SEARCH
# ═════════════════════════════════════════════════════════════
function Invoke-GitHubSearch {
    param(
        [string]$Query,
        [string[]]$Repos = $Global:WebIntelConfig.GitHubRepos,
        [string]$Token = $env:GITHUB_TOKEN
    )

    $headers = @{ 'Accept' = 'application/vnd.github+json' }
    if ($Token) { $headers['Authorization'] = "Bearer $Token" }

    $all = New-Object System.Collections.Generic.List[object]
    $repoQuery = ($Repos | ForEach-Object { "repo:$_" }) -join ' '
    $fullQuery = "$Query $repoQuery"
    $encodedQuery = [uri]::EscapeDataString($fullQuery)

    $url = "https://api.github.com/search/issues?q=$encodedQuery&per_page=$($Global:WebIntelConfig.GitHubPerPage)&sort=updated"

    Write-Host ("  [GitHub] {0}" -f $Query) -ForegroundColor DarkCyan

    $resp = Invoke-WebFetch -Url $url -Headers $headers -ReturnJson
    if (-not $resp -or -not $resp.items) {
        Write-Log "GitHub вернул пустой ответ" "WARN"
        return @()
    }

    foreach ($item in $resp.items) {
        if (-not $item.body) { continue }
        $text = "$($item.title)`n$($item.body)"
        $patterns = Extract-StrategyPatterns -Text $text -Source ("gh:" + $item.html_url)
        foreach ($p in $patterns) { [void]$all.Add($p) }
    }

    Write-Host ("       получено элементов: {0}, паттернов: {1}" -f $resp.items.Count, $all.Count) -ForegroundColor DarkGray
    Start-Sleep -Seconds $Global:WebIntelConfig.RequestDelay
    return @($all.ToArray())
}

# ═════════════════════════════════════════════════════════════
#  NTC.PARTY SEARCH
# ═════════════════════════════════════════════════════════════
function Invoke-NtcPartySearch {
    param([string]$Query)

    $base = $Global:WebIntelConfig.NtcPartyBase
    $encoded = [uri]::EscapeDataString($Query)

    # ntc.party — самописный форум, но у него есть /search?q=
    $url = "$base/search?q=$encoded"
    Write-Host ("  [ntc.party] {0}" -f $Query) -ForegroundColor DarkCyan

    $html = Invoke-WebFetch -Url $url
    if (-not $html) { return @() }

    # Ищем ссылки на темы — они выглядят как /discussion/NNNN/slug
    $threadLinks = @()
    foreach ($m in [regex]::Matches($html, 'href="(/discussion/\d+/[^"]+)"')) {
        $link = $m.Groups[1].Value
        if ($threadLinks -notcontains $link) { $threadLinks += $link }
        if ($threadLinks.Count -ge 5) { break }
    }

    if ($threadLinks.Count -eq 0) {
        Write-Log "ntc.party: ссылки на темы не найдены (структура могла измениться)" "WARN"
        return @()
    }

    Write-Host ("       тем найдено: {0}" -f $threadLinks.Count) -ForegroundColor DarkGray

    $all = New-Object System.Collections.Generic.List[object]
    foreach ($link in $threadLinks) {
        $fullUrl = "$base$link"
        $threadHtml = Invoke-WebFetch -Url $fullUrl
        if (-not $threadHtml) { continue }

        # Грубо вытаскиваем текст постов из HTML
        $plain = $threadHtml -replace '<script[^>]*>.*?</script>', '' `
                             -replace '<style[^>]*>.*?</style>', '' `
                             -replace '<[^>]+>', ' ' `
                             -replace '&nbsp;', ' ' `
                             -replace '&quot;', '"' `
                             -replace '&amp;', '&' `
                             -replace '&lt;', '<' `
                             -replace '&gt;', '>'
        $plain = $plain -replace '\s+', ' '

        $patterns = Extract-StrategyPatterns -Text $plain -Source $fullUrl
        foreach ($p in $patterns) { [void]$all.Add($p) }

        Start-Sleep -Seconds $Global:WebIntelConfig.RequestDelay
    }

    Write-Host ("       паттернов: {0}" -f $all.Count) -ForegroundColor DarkGray
    return @($all.ToArray())
}

# ═════════════════════════════════════════════════════════════
#  DUCKDUCKGO HTML SEARCH (fallback)
# ═════════════════════════════════════════════════════════════
function Invoke-DuckDuckGoSearch {
    param([string]$Query)

    $encoded = [uri]::EscapeDataString($Query)
    $url = "https://html.duckduckgo.com/html/?q=$encoded"
    Write-Host ("  [DDG] {0}" -f $Query) -ForegroundColor DarkCyan

    $html = Invoke-WebFetch -Url $url
    if (-not $html) { return @() }

    # В DDG HTML-версии ссылки — в редиректах uddg=
    $links = @()
    foreach ($m in [regex]::Matches($html, 'uddg=([^&"]+)')) {
        try {
            $decoded = [uri]::UnescapeDataString($m.Groups[1].Value)
            if ($decoded -match '^https?://' -and $links -notcontains $decoded) {
                $links += $decoded
            }
        } catch { }
        if ($links.Count -ge 8) { break }
    }

    if ($links.Count -eq 0) {
        Write-Log "DDG: ссылки не найдены" "WARN"
        return @()
    }

    Write-Host ("       ссылок: {0}" -f $links.Count) -ForegroundColor DarkGray
    Start-Sleep -Seconds $Global:WebIntelConfig.RequestDelay

    $all = New-Object System.Collections.Generic.List[object]
    foreach ($link in $links) {
        # Ограничим: только то, что похоже на текст (не бинарники)
        if ($link -match '\.(png|jpg|gif|zip|exe|dll|pdf)$') { continue }
        $content = Invoke-WebFetch -Url $link
        if (-not $content) { continue }
        $patterns = Extract-StrategyPatterns -Text $content -Source $link
        foreach ($p in $patterns) { [void]$all.Add($p) }
        Start-Sleep -Seconds $Global:WebIntelConfig.RequestDelay
    }

    Write-Host ("       паттернов: {0}" -f $all.Count) -ForegroundColor DarkGray
    return @($all.ToArray())
}

# ═════════════════════════════════════════════════════════════
#  ПРОИЗВОЛЬНЫЙ URL
# ═════════════════════════════════════════════════════════════
function Invoke-UrlScan {
    param([string]$Url)

    Write-Host ("  [URL] {0}" -f $Url) -ForegroundColor DarkCyan
    $content = Invoke-WebFetch -Url $Url
    if (-not $content) { return @() }
    return @(Extract-StrategyPatterns -Text $content -Source $Url)
}

# ═════════════════════════════════════════════════════════════
#  ИЗ ТЕКСТА (пользователь вставил)
# ═════════════════════════════════════════════════════════════
function Invoke-TextScan {
    param([string]$Text)
    return @(Extract-StrategyPatterns -Text $Text -Source "manual-paste")
}

# ═════════════════════════════════════════════════════════════
#  ОРКЕСТРАТОР
# ═════════════════════════════════════════════════════════════
function Invoke-WebIntelSearch {
    param(
        [string]$ProviderName = $Global:ZapretState.ProviderProfile,
        [string[]]$ExtraKeywords = @(),
        [switch]$SkipGitHub,
        [switch]$SkipNtc,
        [switch]$SkipDdg
    )

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       WEB-INTEL — поиск стратегий в интернете            ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Проверяем, задан ли провайдер
    if (-not $ProviderName) {
        Write-Log "Провайдер не определён — использую общий поиск" "WARN"
        $ProviderName = ""
    }

    # Ключевые слова
    $baseKeywords = @(
        'winws2','zapret2','lua-desync','dpi-desync',
        'fake:blob','multisplit','fakeddisorder','hostfakesplit'
    )
    $providerKeywords = @()
    if ($ProviderName -and $ProviderName -ne 'default') {
        $providerKeywords += $ProviderName
        # Русские варианты
        switch -Regex ($ProviderName) {
            'Rostelecom' { $providerKeywords += @('Ростелеком','rt.ru') }
            'MTS'        { $providerKeywords += @('МТС','MTS') }
            'Beeline'    { $providerKeywords += @('Билайн','VimpelCom') }
            'Megafon'    { $providerKeywords += @('Мегафон','MegaFon') }
            'ER-Telecom' { $providerKeywords += @('Дом.ру','DOM.RU') }
            'TTK'        { $providerKeywords += @('ТТК','TransTeleCom') }
            'MGTS'       { $providerKeywords += @('МГТС','MGTS') }
            'Tele2'      { $providerKeywords += @('Теле2') }
            'Yota'       { $providerKeywords += @('Йота') }
        }
    }
    $keywords = @($providerKeywords + $ExtraKeywords + $baseKeywords) | Select-Object -Unique

    Write-Host ("  Провайдер: {0}" -f $(if ($ProviderName) { $ProviderName } else { '<не задан>' })) -ForegroundColor Gray
    Write-Host ("  Ключевые слова: {0}" -f ($keywords -join ', ')) -ForegroundColor DarkGray
    Write-Host ""

    $allPatterns = New-Object System.Collections.Generic.List[object]

    # ─── 1. GitHub ───
    if (-not $SkipGitHub) {
        Write-Host "  ─── GitHub Issues ─────────────────────────────────────" -ForegroundColor DarkCyan

        # Несколько запросов (по провайдеру и общий)
        $queries = @()
        if ($providerKeywords.Count -gt 0) {
            $queries += ($providerKeywords[0] + ' lua-desync')
            $queries += ($providerKeywords[0] + ' dpi-desync')
        }
        $queries += @(
            'winws2 lua-desync fake',
            'zapret2 lua-desync multisplit',
            'zapret2 fakeddisorder'
        )
        $queries = $queries | Select-Object -Unique

        foreach ($q in $queries) {
            $res = Invoke-GitHubSearch -Query $q
            foreach ($p in $res) { [void]$allPatterns.Add($p) }
        }
    }

    # ─── 2. ntc.party ───
    if (-not $SkipNtc) {
        Write-Host ""
        Write-Host "  ─── ntc.party ─────────────────────────────────────────" -ForegroundColor DarkCyan
        $ntcQueries = @()
        if ($providerKeywords.Count -gt 0) { $ntcQueries += $providerKeywords[0] }
        $ntcQueries += 'zapret2 winws2'
        $ntcQueries = $ntcQueries | Select-Object -Unique

        foreach ($q in $ntcQueries) {
            $res = Invoke-NtcPartySearch -Query $q
            foreach ($p in $res) { [void]$allPatterns.Add($p) }
        }
    }

    # ─── 3. DuckDuckGo ───
    if (-not $SkipDdg) {
        Write-Host ""
        Write-Host "  ─── DuckDuckGo ────────────────────────────────────────" -ForegroundColor DarkCyan
        $ddgQueries = @()
        if ($providerKeywords.Count -gt 0) {
            $ddgQueries += ("zapret2 winws2 " + $providerKeywords[0] + " lua-desync")
        }
        $ddgQueries += 'zapret2 lua-desync fake multisplit config'
        $ddgQueries = $ddgQueries | Select-Object -Unique

        foreach ($q in $ddgQueries) {
            $res = Invoke-DuckDuckGoSearch -Query $q
            foreach ($p in $res) { [void]$allPatterns.Add($p) }
        }
    }

    # ─── Итог ───
    Write-Host ""
    Write-Host ("  Всего извлечено паттернов: {0}" -f $allPatterns.Count) -ForegroundColor Yellow

    if ($allPatterns.Count -eq 0) {
        Write-Host "  Ничего не найдено. Возможные причины:" -ForegroundColor DarkYellow
        Write-Host "    • GitHub rate-limit (без токена: 10 запросов/мин)" -ForegroundColor Gray
        Write-Host "    • ntc.party изменил структуру" -ForegroundColor Gray
        Write-Host "    • Поставь GITHUB_TOKEN в env для большего лимита" -ForegroundColor Gray
        return 0
    }

    # Фильтр: только интересные (полные или winws2-фрагменты)
    $good = @($allPatterns | Where-Object {
        $_.Engine -eq 'winws2' -or $_.Completeness -like '*winws2*' -or
        $_.Completeness -like 'full-*'
    })

    if ($good.Count -eq 0) { $good = @($allPatterns) }

    $added = Add-DiscoveredPatterns -Patterns $good -SourceTag "webintel"
    Write-Host ("  Добавлено в базу: {0}" -f $added) -ForegroundColor Green
    Write-Host ("  Файл: {0}" -f (Get-WebIntelDbPath)) -ForegroundColor DarkGray

    return $added
}

# ═════════════════════════════════════════════════════════════
#  ПОЛУЧИТЬ НЕПРОВЕРЕННЫЕ СТРАТЕГИИ ДЛЯ AUTO-FIND
# ═════════════════════════════════════════════════════════════
function Get-DiscoveredStrategies {
    param(
        [switch]$UntestedOnly,
        [int]$Max = 30,
        [string]$Engine = 'winws2'
    )

    $db = Load-WebIntelDb
    $items = @($db.Strategies)
    if ($items.Count -eq 0) { return @() }

    # Фильтр по движку
    if ($Engine) {
        $items = @($items | Where-Object { $_.Engine -eq $Engine -or $_.Engine -eq 'unknown' })
    }

    # Только непроверенные
    if ($UntestedOnly) {
        $items = @($items | Where-Object { -not $_.Tested })
    }

    # Сортируем: сначала те, что встречались чаще (SeenCount) и раньше всего
    $items = @($items | Sort-Object -Property @{Expression={[int]$_.SeenCount};Descending=$true},
                                            @{Expression={$_.FirstSeen};Descending=$false})

    if ($Max -gt 0 -and $items.Count -gt $Max) {
        $items = @($items | Select-Object -First $Max)
    }

    return $items
}

function Update-DiscoveredStrategyScore {
    param(
        [string]$Candidate,
        [int]$Score,
        [int]$Total
    )
    if (-not $Candidate) { return }

    $db = Load-WebIntelDb
    $key = $Candidate.ToLowerInvariant()
    $changed = $false
    foreach ($s in $db.Strategies) {
        if ($s.Candidate -and $s.Candidate.ToLowerInvariant() -eq $key) {
            $s.Tested     = $true
            $s.TestScore  = $Score
            $s.TestTotal  = $Total
            $s.LastTested = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $changed = $true
            break
        }
    }
    if ($changed) { Save-WebIntelDb -Db $db }
}

# ═════════════════════════════════════════════════════════════
#  МЕНЮ
# ═════════════════════════════════════════════════════════════
function Show-WebIntelMenu {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host "          WEB-INTEL — поиск стратегий в интернете             " -ForegroundColor Cyan
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host ""

        $db = Load-WebIntelDb
        $total   = @($db.Strategies).Count
        $tested  = @($db.Strategies | Where-Object { $_.Tested }).Count
        $working = @($db.Strategies | Where-Object { $_.Tested -and $_.TestScore -gt 0 }).Count

        Write-Host ("  База:        {0}" -f (Get-WebIntelDbPath)) -ForegroundColor DarkCyan
        Write-Host ("  Всего:       {0}" -f $total) -ForegroundColor Gray
        Write-Host ("  Проверено:   {0}" -f $tested) -ForegroundColor $(if ($tested -gt 0) { "Yellow" } else { "DarkGray" })
        Write-Host ("  Рабочих:     {0}" -f $working) -ForegroundColor $(if ($working -gt 0) { "Green" } else { "DarkGray" })
        Write-Host ("  Обновлено:   {0}" -f $db.Updated) -ForegroundColor DarkGray
        Write-Host ""

        if ($env:GITHUB_TOKEN) {
            Write-Host "  GitHub Token: УСТАНОВЛЕН (лимит 30/мин)" -ForegroundColor Green
        } else {
            Write-Host "  GitHub Token: НЕТ (лимит 10/мин, поиск медленный)" -ForegroundColor DarkYellow
            Write-Host '    setx GITHUB_TOKEN "ghp_xxxxx"  ->  перезапустить' -ForegroundColor DarkGray
        }
        Write-Host ""

        Write-Host "  ─── Поиск ────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "   1. Полный поиск (GitHub + ntc.party + DDG)" -ForegroundColor Yellow
        Write-Host "   2. Только GitHub Issues"
        Write-Host "   3. Только ntc.party"
        Write-Host "   4. Только DuckDuckGo"
        Write-Host "   5. Произвольный URL"
        Write-Host "   6. Из текста (вставить вручную)"
        Write-Host ""
        Write-Host "  ─── Просмотр базы ────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "   7. Показать все найденные"
        Write-Host "   8. Показать непроверенные"
        Write-Host "   9. Показать рабочие (TestScore > 0)" -ForegroundColor Green
        Write-Host "  10. Экспорт в .txt (для ResultComposer)"
        Write-Host "  11. Очистить всю базу" -ForegroundColor Red
        Write-Host ""
        Write-Host "   0. Назад" -ForegroundColor DarkGray
        Write-Host ""
        $c = Read-Host "Номер"

        switch ($c) {
            "1" {
                $added = Invoke-WebIntelSearch
                Write-Host ""
                Write-Host ("  Итого добавлено в базу: {0}" -f $added) -ForegroundColor Green
                Read-Host "  Enter..."
            }
            "2" {
                $added = Invoke-WebIntelSearch -SkipNtc -SkipDdg
                Write-Host ""
                Write-Host ("  Итого добавлено в базу: {0}" -f $added) -ForegroundColor Green
                Read-Host "  Enter..."
            }
            "3" {
                $added = Invoke-WebIntelSearch -SkipGitHub -SkipDdg
                Write-Host ""
                Write-Host ("  Итого добавлено в базу: {0}" -f $added) -ForegroundColor Green
                Read-Host "  Enter..."
            }
            "4" {
                $added = Invoke-WebIntelSearch -SkipGitHub -SkipNtc
                Write-Host ""
                Write-Host ("  Итого добавлено в базу: {0}" -f $added) -ForegroundColor Green
                Read-Host "  Enter..."
            }
            "5" {
                $url = (Read-Host "URL").Trim()
                if (-not $url) { continue }
                $patterns = Invoke-UrlScan -Url $url
                if ($patterns.Count -gt 0) {
                    $added = Add-DiscoveredPatterns -Patterns $patterns -SourceTag "url:$url"
                    Write-Host ("  Добавлено: {0}" -f $added) -ForegroundColor Green
                } else {
                    Write-Host "  Паттернов не найдено" -ForegroundColor Yellow
                }
                Read-Host "  Enter..."
            }
            "6" {
                Write-Host ""
                Write-Host "  Вставь текст (Enter дважды для завершения):" -ForegroundColor DarkCyan
                $lines = @()
                while ($true) {
                    $ln = Read-Host
                    if ([string]::IsNullOrEmpty($ln) -and $lines.Count -gt 0) { break }
                    $lines += $ln
                }
                $text = $lines -join "`n"
                $patterns = Invoke-TextScan -Text $text
                if ($patterns.Count -gt 0) {
                    $added = Add-DiscoveredPatterns -Patterns $patterns -SourceTag "manual"
                    Write-Host ("  Добавлено: {0}" -f $added) -ForegroundColor Green
                } else {
                    Write-Host "  Паттернов не найдено" -ForegroundColor Yellow
                }
                Read-Host "  Enter..."
            }
            "7" {
                $db = Load-WebIntelDb
                $items = @($db.Strategies)
                if ($items.Count -eq 0) { Write-Host "  База пуста" -ForegroundColor DarkGray; Read-Host "  Enter..."; continue }
                Write-Host ""
                $i = 0
                foreach ($s in $items) {
                    $i++
                    $col = if ($s.Tested -and $s.TestScore -gt 0) { "Green" }
                           elseif ($s.Tested) { "DarkGray" }
                           else { "White" }
                    $short = if ($s.Candidate.Length -gt 100) { $s.Candidate.Substring(0,97) + "..." } else { $s.Candidate }
                    Write-Host ("  [{0,3}] {1}" -f $i, $short) -ForegroundColor $col
                    Write-Host ("        src={0}  seen={1}  tested={2}" -f $s.SourceTag, $s.SeenCount, $s.Tested) -ForegroundColor DarkGray
                }
                Read-Host "  Enter..."
            }
            "8" {
                $items = Get-DiscoveredStrategies -UntestedOnly -Max 50
                if ($items.Count -eq 0) { Write-Host "  Нет непроверенных" -ForegroundColor DarkGray; Read-Host "  Enter..."; continue }
                Write-Host ""
                foreach ($s in $items) {
                    $short = if ($s.Candidate.Length -gt 100) { $s.Candidate.Substring(0,97) + "..." } else { $s.Candidate }
                    Write-Host ("  • {0}" -f $short) -ForegroundColor White
                }
                Read-Host "  Enter..."
            }
            "9" {
                $db = Load-WebIntelDb
                $items = @($db.Strategies | Where-Object { $_.Tested -and $_.TestScore -gt 0 } |
                           Sort-Object -Property @{Expression={$_.TestScore};Descending=$true})
                if ($items.Count -eq 0) { Write-Host "  Нет рабочих" -ForegroundColor DarkGray; Read-Host "  Enter..."; continue }
                Write-Host ""
                foreach ($s in $items) {
                    Write-Host ("  [{0}/{1}] {2}" -f $s.TestScore, $s.TestTotal, $s.Candidate) -ForegroundColor Green
                }
                Read-Host "  Enter..."
            }
            "10" {
                $db = Load-WebIntelDb
                $items = @($db.Strategies)
                if ($items.Count -eq 0) { Write-Host "  База пуста" -ForegroundColor DarkGray; Read-Host "  Enter..."; continue }
                $root = Split-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) -Parent
                $out  = Join-Path $root 'resultats\discovered.txt'
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.AppendLine("# ===============================================================")
                [void]$sb.AppendLine("# WebIntel — discovered strategies")
                [void]$sb.AppendLine("# Экспорт: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
                [void]$sb.AppendLine("# Всего: $($items.Count)")
                [void]$sb.AppendLine("# ===============================================================")
                [void]$sb.AppendLine("")
                $rank = 0
                foreach ($s in $items) {
                    $rank++
                    [void]$sb.AppendLine(("# #{0}  score={1}/{2}  src={3}" -f $rank, $s.TestScore, $s.TestTotal, $s.SourceTag))
                    [void]$sb.AppendLine("--new")
                    [void]$sb.AppendLine($s.Candidate)
                    [void]$sb.AppendLine("")
                }
                [IO.File]::WriteAllText($out, $sb.ToString(), [Text.UTF8Encoding]::new($false))
                Write-Host ("  Файл: {0}" -f $out) -ForegroundColor Green
                Read-Host "  Enter..."
            }
            "11" {
                Write-Host "  Удалить всю базу? Введи 'yes'" -ForegroundColor Red
                $ans = Read-Host
                if ($ans -eq 'yes') {
                    $file = Get-WebIntelDbPath
                    if (Test-Path $file) { Remove-Item $file -Force }
                    Write-Host "  База очищена" -ForegroundColor Green
                }
                Read-Host "  Enter..."
            }
            "0" { return }
        }
    }
}