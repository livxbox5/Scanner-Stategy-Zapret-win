# ===============================================================
# === PROVIDER (Provider.ps1) — winws2 / zapret2 ===
# ===============================================================
#  Авто-детект ISP через ip-api.com, встроенные presets,
#  база найденных стратегий в config/providers.json.
#  Фокус-режим: генерация только под текущего провайдера.
# ===============================================================

$script:ProviderPresets = @{

    'Rostelecom' = @{
        Patterns   = @('Rostelecom','Ростелеком','Rt\.ru','Rostelecom PJSC',
                       'Macroregional Branch South','Karachaevo-Cherkess')
        LuaMethods = @('fake','multisplit','multidisorder','fakeddisorder','hostfakesplit','syndata')
        Splits     = @('1','2','midsld','sniext+1','host','host+1','endhost')
        Repeats    = @('repeats=2','repeats=4','repeats=6')
        TlsMods    = @('rnd','rnd,rndsni','rnd,dupsid','sni=www.google.com')
        BlobFiles  = @(
            'tls_clienthello_www_google_com.bin',
            'tls_clienthello_max_ru.bin',
            'quic_initial_rutube_ru.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_clienthello_www_google_com.bin, quic_initial_rutube_ru.bin'
        Note       = 'Ростелеком (в т.ч. Юг): fake + multisplit, tls_mod=rnd,rndsni, repeats 2-6'
    }

    'MTS' = @{
        Patterns   = @('MTS','МТС','Mobile TeleSystems','MTS PJSC')
        LuaMethods = @('fake','multisplit','multidisorder','fakeddisorder','hostfakesplit')
        Splits     = @('1','2','midsld','sniext+1')
        Repeats    = @('repeats=4','repeats=6','repeats=8')
        TlsMods    = @('rnd,rndsni','rnd,dupsid,rndsni','sni=www.google.com')
        BlobFiles  = @('tls_clienthello_www_google_com.bin','quic_initial_www_google_com.bin')
        Fool       = @()
        BlobHint   = 'tls_clienthello_www_google_com.bin, quic_initial_www_google_com.bin'
        Note       = 'МТС: fake + multidisorder, tls_mod=rnd,rndsni'
    }

    'Beeline' = @{
        Patterns   = @('Beeline','Билайн','VimpelCom','Vimpel-Communications')
        LuaMethods = @('fake','multidisorder','multisplit','fakeddisorder','hostfakesplit')
        Splits     = @('1','2','midsld','host')
        Repeats    = @('repeats=4','repeats=6')
        TlsMods    = @('rnd,dupsid','rnd,rndsni')
        BlobFiles  = @('tls_clienthello_4pda_to.bin','quic_initial_4pda_to.bin')
        Fool       = @()
        BlobHint   = 'tls_clienthello_4pda_to.bin, quic_initial_4pda_to.bin'
        Note       = 'Билайн: multidisorder с tls_mod=rnd,dupsid'
    }

    'Megafon' = @{
        Patterns   = @('Megafon','Мегафон','MegaFon','MegaFon PJSC')
        LuaMethods = @('fake','multisplit','fakeddisorder','hostfakesplit','syndata')
        Splits     = @('1','2','midsld','sniext+1')
        Repeats    = @('repeats=2','repeats=4','repeats=6')
        TlsMods    = @('sni=www.google.com','rnd,rndsni')
        BlobFiles  = @('tls_clienthello_5ka_ru.bin','quic_initial_5ka_ru.bin')
        Fool       = @()
        BlobHint   = 'tls_clienthello_5ka_ru.bin, quic_initial_5ka_ru.bin'
        Note       = 'Мегафон: fake + fakeddisorder, tls_mod=sni=www.google.com'
    }

    'ER-Telecom' = @{
        Patterns   = @('ER-Telecom','Дом\.ру','DOM\.RU','ER-Telecom Holding')
        LuaMethods = @('fake','multisplit','multidisorder','hostfakesplit')
        Splits     = @('1','sniext+1','midsld')
        Repeats    = @('repeats=2','repeats=4')
        TlsMods    = @('rnd','rnd,rndsni')
        BlobFiles  = @('tls_clienthello_max_ru.bin','quic_initial_tencent_com.bin')
        Fool       = @()
        BlobHint   = 'tls_clienthello_max_ru.bin, quic_initial_tencent_com.bin'
        Note       = 'Дом.ру: fake + multisplit, pos=1,sniext+1'
    }

    'TTK' = @{
        Patterns   = @('TTK','ТТК','TransTeleCom','TransTelecom')
        LuaMethods = @('fake','multidisorder','multisplit','fakeddisorder')
        Splits     = @('1','2','midsld')
        Repeats    = @('repeats=4','repeats=6')
        TlsMods    = @('rnd','rnd,rndsni')
        BlobFiles  = @('tls_clienthello_www_sferum_ru.bin')
        Fool       = @()
        BlobHint   = 'tls_clienthello_www_sferum_ru.bin'
        Note       = 'ТТК: fake + multidisorder, repeats=4'
    }

    'MGTS' = @{
        Patterns   = @('MGTS','МГТС','Moscow City Telephone')
        LuaMethods = @('fake','multisplit','fakeddisorder','hostfakesplit')
        Splits     = @('midsld','1','2')
        Repeats    = @('repeats=2','repeats=4')
        TlsMods    = @('rnd,rndsni')
        BlobFiles  = @('tls_clienthello_www_google_com.bin')
        Fool       = @()
        BlobHint   = 'tls_clienthello_www_google_com.bin'
        Note       = 'МГТС: fake + multisplit, pos=midsld'
    }

    'Tele2' = @{
        Patterns   = @('Tele2','Теле2','Tele2 Russia')
        LuaMethods = @('fake','multisplit','multidisorder','hostfakesplit')
        Splits     = @('1','2','midsld')
        Repeats    = @('repeats=2','repeats=4')
        TlsMods    = @('rnd','rnd,rndsni')
        BlobFiles  = @('quic_initial_steamcommunity_com.bin')
        Fool       = @()
        BlobHint   = 'quic_initial_steamcommunity_com.bin'
        Note       = 'Tele2: fake + multisplit, tls_mod=rnd'
    }

    'Yota' = @{
        Patterns   = @('Yota','Йота','Scartel')
        LuaMethods = @('fake','multisplit','fakeddisorder','hostfakesplit','syndata')
        Splits     = @('sniext+1','1','midsld')
        Repeats    = @('repeats=2','repeats=4')
        TlsMods    = @('rnd,rndsni')
        BlobFiles  = @('tls_clienthello_4pda_to.bin')
        Fool       = @()
        BlobHint   = 'tls_clienthello_4pda_to.bin'
        Note       = 'Yota: fake + fakeddisorder, pos=sniext+1'
    }

    'default' = @{
        Patterns   = @()
        LuaMethods = @('fake','multisplit','multidisorder','fakeddisorder','hostfakesplit','syndata')
        Splits     = @('1','2','midsld','sniext+1','host','host+1','endhost','endhost-1',
                       'midsld-2','midsld+2','method+2',
                       '1,sniext+1,host+1,midsld-2,midsld,midsld+2,endhost-1')
        Repeats    = @('repeats=1','repeats=2','repeats=4','repeats=6','repeats=8')
        TlsMods    = @('rnd','rnd,rndsni','rnd,dupsid','rnd,dupsid,rndsni',
                       'sni=www.google.com','sni=ya.ru')
        BlobFiles  = @()
        Fool       = @()
        BlobHint   = 'fake_default_tls, fake_default_quic'
        Note       = 'Универсальный набор: полный перебор методов и blob-ов'
    }
}

# ─────────────────────────────────────────────────────────────
#  Определение провайдера
# ─────────────────────────────────────────────────────────────
function Get-ProviderInfo {
    param([switch]$Force)

    $cacheFile = Join-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) 'provider.json'

    if (-not $Force -and (Test-Path $cacheFile)) {
        $age = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
        if ($age.TotalHours -lt 6) {
            try {
                $obj = (Get-Content $cacheFile -Raw -Encoding UTF8) | ConvertFrom-Json
                if ($obj -and $obj.ISP) { return $obj }
            } catch { }
        }
    }

    $info = [pscustomobject]@{
        IP = ""; ISP = ""; Org = ""; City = ""; Region = ""
        Country = ""; AS = ""; ASN = ""; Err = ""
    }

    try {
        $url = "http://ip-api.com/json/?fields=status,message,country,regionName,city,isp,org,as,asname,query"
        $resp = Invoke-RestMethod -Uri $url -TimeoutSec 8 -ErrorAction Stop

        if ($resp.status -eq "success") {
            $info.IP      = [string]$resp.query
            $info.ISP     = [string]$resp.isp
            $info.Org     = [string]$resp.org
            $info.City    = [string]$resp.city
            $info.Region  = [string]$resp.regionName
            $info.Country = [string]$resp.country
            $info.AS      = [string]$resp.as
            if ($info.AS -match '^(AS\d+)') { $info.ASN = $Matches[1] }
        } else {
            $info.Err = "ip-api: $($resp.message)"
        }
    } catch {
        $info.Err = $_.Exception.Message
    }

    try { $info | ConvertTo-Json | Set-Content -Path $cacheFile -Encoding UTF8 } catch { }
    return $info
}

function Find-ProviderProfile {
    param([string]$IspName, [string]$Org, [string]$ASN)

    $text = "$IspName $Org $ASN"
    if (-not $text.Trim()) { return 'default' }

    $clean = $text -replace '(?i)(ООО|ОАО|ЗАО|ПАО|АО|LLC|Ltd|Inc|JSC|PJSC|LTD|LIMITED)\s*',''
    $clean = $clean -replace '[«»"''`]',''
    $clean = $clean.Trim()

    foreach ($key in $script:ProviderPresets.Keys) {
        if ($key -eq 'default') { continue }
        $p = $script:ProviderPresets[$key]
        foreach ($pattern in $p.Patterns) {
            if ($clean -match $pattern -or $text -match $pattern) {
                return $key
            }
        }
    }
    return 'default'
}

function Get-ProviderPreset {
    param([string]$ProfileName)
    if ($script:ProviderPresets.ContainsKey($ProfileName)) {
        return $script:ProviderPresets[$ProfileName]
    }
    return $script:ProviderPresets['default']
}

# ─────────────────────────────────────────────────────────────
#  Текущий профиль → state + settings.yml
# ─────────────────────────────────────────────────────────────
function Set-CurrentProviderProfile {
    param([string]$ProfileName)
    if (-not $ProfileName) { return }
    if ($Global:ZapretState.ProviderProfile -ne $ProfileName) {
        $Global:ZapretState.ProviderProfile = $ProfileName
        Save-Settings
    }
}

# ─────────────────────────────────────────────────────────────
#  Фокус-параметры провайдера
# ─────────────────────────────────────────────────────────────
function Get-ProviderFocusParams {
    $profile = $Global:ZapretState.ProviderProfile
    if (-not $profile) { return $null }
    if ($profile -eq 'default') { return $null }  # default = полный перебор
    $preset = Get-ProviderPreset -ProfileName $profile
    if (-not $preset) { return $null }

    return [pscustomobject]@{
        Profile    = $profile
        Splits     = @($preset.Splits     | Where-Object { $_ })
        Repeats    = @($preset.Repeats    | Where-Object { $_ })
        TlsMods    = @($preset.TlsMods    | Where-Object { $_ })
        BlobFiles  = @($preset.BlobFiles  | Where-Object { $_ })
        LuaMethods = @($preset.LuaMethods | Where-Object { $_ })
        Fool       = @($preset.Fool       | Where-Object { $_ })
    }
}

function Apply-ProviderPreset {
    param([string]$ProfileName)

    Set-CurrentProviderProfile -ProfileName $ProfileName

    $preset = Get-ProviderPreset -ProfileName $ProfileName

    if ($preset.LuaMethods) {
        $Global:ZapretState.LuaMethods = @($preset.LuaMethods)
    }

    Write-Host ("  Применён preset '{0}' (winws2/Lua)" -f $ProfileName) -ForegroundColor Gray
    Write-Host ("    LuaMethods : {0}" -f ($preset.LuaMethods -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Splits     : {0}" -f ($preset.Splits    -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Repeats    : {0}" -f ($preset.Repeats   -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    TlsMods    : {0}" -f ($preset.TlsMods   -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    BlobFiles  : {0}" -f ($preset.BlobFiles -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Blob hint  : {0}" -f $preset.BlobHint) -ForegroundColor DarkGray
    Write-Host ("    Note       : {0}" -f $preset.Note) -ForegroundColor DarkYellow

    $loadedFiles = @($Global:ZapretState.LuaBlobFileMap.Values)
    $hintFiles = @($preset.BlobHint -split ',\s*' | ForEach-Object { $_.Trim() })
    $missing = @($hintFiles | Where-Object { $_ -and $loadedFiles -notcontains $_ })

    if ($missing.Count -gt 0) {
        Write-Host ("    [!] Рекомендуется добавить blob-файлы: {0}" -f ($missing -join ', ')) -ForegroundColor Yellow
    }
}

# ─────────────────────────────────────────────────────────────
#  База стратегий провайдера
# ─────────────────────────────────────────────────────────────
function Get-ProviderDbPath {
    $cfg = Split-Path $Global:ZapretState.ConfigFile -Parent
    return (Join-Path $cfg 'providers.json')
}

function Load-ProviderDb {
    $file = Get-ProviderDbPath

    $empty = [pscustomobject]@{
        Version   = 1
        Providers = [pscustomobject]@{}
    }

    if (-not (Test-Path $file)) { return $empty }

    try {
        $raw = Get-Content $file -Raw -Encoding UTF8
        if (-not $raw -or $raw.Trim() -eq '') { return $empty }

        $obj = $raw | ConvertFrom-Json
        if (-not $obj) { return $empty }

        if (-not $obj.PSObject.Properties['Providers']) {
            $obj | Add-Member -NotePropertyName Providers `
                             -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        return $obj
    } catch {
        return $empty
    }
}

function Save-ProviderDb {
    param($Db)
    $file = Get-ProviderDbPath
    try {
        $json = $Db | ConvertTo-Json -Depth 8
        $enc  = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file, $json, $enc)
    } catch {
        Write-Log "Ошибка сохранения базы: $_" "ERR"
    }
}

function Save-ProviderStrategy {
    param(
        [string]$ProfileName,
        [string]$Strategy,
        [int]$Score = 0,
        [int]$Total = 0
    )

    if (-not $ProfileName -or -not $Strategy) { return }

    $db = Load-ProviderDb

    if (-not $db.Providers.$ProfileName) {
        $db.Providers | Add-Member -NotePropertyName $ProfileName -NotePropertyValue ([pscustomobject]@{
            ISP = $ProfileName
            Created = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            LastUpdate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            Strategies = @()
        }) -Force
    }

    $entry = $db.Providers.$ProfileName
    $strategies = @($entry.Strategies)

    $exists = $false
    foreach ($s in $strategies) {
        if ($s.Cmd -eq $Strategy) {
            if ($Score -gt $s.Score) {
                $s.Score = $Score
                $s.Total = $Total
                $s.LastSeen = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            }
            $exists = $true
            break
        }
    }

    if (-not $exists) {
        $newStrat = [pscustomobject]@{
            Cmd        = $Strategy
            Score      = $Score
            Total      = $Total
            FirstSeen  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            LastSeen   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
        $strategies = @($strategies + $newStrat)
        $entry.Strategies = $strategies
    }

    $entry.LastUpdate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Save-ProviderDb -Db $db
}

function Get-KnownStrategies {
    param([string]$ProfileName)

    $db = Load-ProviderDb
    if (-not $db.Providers.$ProfileName) { return @() }
    $entry = $db.Providers.$ProfileName
    if (-not $entry.Strategies) { return @() }

    return @($entry.Strategies | Sort-Object -Property @{Expression={$_.Score};Descending=$true})
}

# ─────────────────────────────────────────────────────────────
#  Инфо о провайдере
# ─────────────────────────────────────────────────────────────
function Show-ProviderInfo {
    Write-Host ""
    Write-Host "  ─── ПРОВАЙДЕР ──────────────────────────────" -ForegroundColor DarkMagenta

    $info = Get-ProviderInfo
    if ($info.Err) {
        Write-Host ("  [!] Не удалось определить: {0}" -f $info.Err) -ForegroundColor Yellow
        Write-Host "  ────────────────────────────────────────────" -ForegroundColor DarkMagenta
        return $null
    }

    $profile = Find-ProviderProfile -IspName $info.ISP -Org $info.Org -ASN $info.ASN

    Write-Host ("  IP:        {0}" -f $info.IP) -ForegroundColor Gray
    Write-Host ("  Провайдер: {0}" -f $info.ISP) -ForegroundColor Gray
    Write-Host ("  Организ.:  {0}" -f $info.Org) -ForegroundColor Gray
    Write-Host ("  Город:     {0}, {1}" -f $info.City, $info.Region) -ForegroundColor Gray
    Write-Host ("  AS:        {0}" -f $info.AS) -ForegroundColor Gray
    Write-Host ("  Профиль:   {0}" -f $profile) -ForegroundColor Green

    $known = Get-KnownStrategies -ProfileName $profile
    if ($known.Count -gt 0) {
        Write-Host ("  Известных: {0} рабочих стратегий (сохранены ранее)" -f $known.Count) -ForegroundColor Green
    } else {
        Write-Host "  Известных: нет (нужен первый тест)" -ForegroundColor DarkGray
    }

    Write-Host "  ────────────────────────────────────────────" -ForegroundColor DarkMagenta
    Write-Host ""

    return [pscustomobject]@{
        Info    = $info
        Profile = $profile
        Known   = $known
    }
}

# ─────────────────────────────────────────────────────────────
#  Готовая длинная команда для текущего провайдера
# ─────────────────────────────────────────────────────────────
function Build-ProviderCommand {
    param(
        [ValidateSet('fake+multisplit','fake+multidisorder','fake+fakeddisorder','hostfakesplit','fake+syndata')]
        [string]$Kind = 'fake+multisplit',

        [string]$SplitPos = '1',
        [string]$Repeats  = 'repeats=4',
        [string]$TlsMod   = 'rnd,rndsni',
        [string]$BlobFile = ''
    )

    $ready = Test-Winws2Ready
    if (-not $ready.Ready) {
        Write-Log "winws2 не готов:" "ERR"
        $ready.Issues | ForEach-Object { Write-Log "  - $_" "ERR" }
        return $null
    }

    $luaInit = Get-Winws2LuaInit

    if (-not $BlobFile) {
        $focus = Get-ProviderFocusParams
        if ($focus -and $focus.BlobFiles.Count -gt 0) { $BlobFile = $focus.BlobFiles[0] }
    }
    $blobKey = $null
    if ($BlobFile) {
        foreach ($k in $Global:ZapretState.LuaBlobFileMap.Keys) {
            if ($Global:ZapretState.LuaBlobFileMap[$k] -ieq $BlobFile) { $blobKey = $k; break }
        }
    }
    if (-not $blobKey) { $blobKey = 'tls_google' }

    $blobDef = Get-Winws2BlobDefs

    $hl = ""
    $he = ""
    if ($Global:ZapretState.TxtPath -and (Test-Path $Global:ZapretState.TxtPath)) {
        $name = $Global:ZapretState.Hostlist
        if (-not $name) { $name = 'list-general.txt' }
        $f = Join-Path $Global:ZapretState.TxtPath $name
        if (Test-Path $f) { $hl = " --hostlist=`"$($f -replace '\\','/')`"" }

        # ─── Глобальные exclude: list-exclude.txt + list-exclude-user.txt ───
        foreach ($n in @('list-exclude.txt','list-exclude-user.txt') | Select-Object -Unique) {
            $ef = Join-Path $Global:ZapretState.TxtPath $n
            if (Test-Path $ef) {
                $he += " --hostlist-exclude=`"$($ef -replace '\\','/')`""
            }
        }
    }

    $foolSuf = Get-Winws2FoolSuffix
    $globExt = Get-Winws2GlobalExtras

    $wf = "--wf-tcp-out=443 --wf-tcp-in=443 --wf-udp-out=443 --wf-udp-in=443"
    $head = "$wf$he $luaInit $blobDefs $globExt".Trim()

    $action = switch ($Kind) {
        'fake+multisplit' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=known " +
            "--lua-desync=fake:blob=$blobKey`:tls_mod=$TlsMod`:$Repeats$foolSuf " +
            "--lua-desync=multisplit`:pos=$SplitPos$foolSuf"
        }
        'fake+multidisorder' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=known " +
            "--lua-desync=fake:blob=$blobKey`:$Repeats$foolSuf " +
            "--lua-desync=multidisorder`:pos=$SplitPos$foolSuf"
        }
        'fake+fakeddisorder' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=known " +
            "--lua-desync=fake:blob=$blobKey`:repeats=2$foolSuf " +
            "--lua-desync=fakeddisorder`:pos=$SplitPos$foolSuf"
        }
        'hostfakesplit' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=known " +
            "--lua-desync=hostfakesplit`:host=www.google.com`:altorder=1$foolSuf"
        }
        'fake+syndata' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=known " +
            "--lua-desync=fake:blob=$blobKey`:repeats=2$foolSuf " +
            "--lua-desync=syndata$foolSuf"
        }
    }

    return "$head $action"
}

function Show-ProviderReadyCommands {
    $ctx = Show-ProviderInfo
    if (-not $ctx) { return }

    Set-CurrentProviderProfile -ProfileName $ctx.Profile

    $focus = Get-ProviderFocusParams
    if (-not $focus) {
        Write-Log "Нет фокус-параметров для профиля '$($ctx.Profile)' (default = полный перебор)" "WARN"
        Write-Host ""
        Write-Host "  Для default-профиля используй пункт 10 (АВТО-ТЕСТ)." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Enter..."
        return
    }

    Write-Host ""
    Write-Host ("  Провайдер: {0}" -f $ctx.Profile) -ForegroundColor Magenta
    Write-Host ("  Splits   : {0}" -f ($focus.Splits     -join ', ')) -ForegroundColor DarkGray
    Write-Host ("  Repeats  : {0}" -f ($focus.Repeats    -join ', ')) -ForegroundColor DarkGray
    Write-Host ("  TlsMods  : {0}" -f ($focus.TlsMods    -join ', ')) -ForegroundColor DarkGray
    Write-Host ("  Blobs    : {0}" -f ($focus.BlobFiles  -join ', ')) -ForegroundColor DarkGray
    Write-Host ""

    $topRepeats = if ($focus.Repeats.Count) { $focus.Repeats[0] } else { 'repeats=4' }
    $topTlsMod  = if ($focus.TlsMods.Count) { $focus.TlsMods[0] } else { 'rnd,rndsni' }
    $topSplit   = if ($focus.Splits.Count)  { $focus.Splits[0] }  else { '1' }

    $presets = @(
        @{ Kind = 'fake+multisplit';    P = $topSplit; R = $topRepeats;  M = $topTlsMod },
        @{ Kind = 'fake+multidisorder'; P = $topSplit; R = $topRepeats;  M = $topTlsMod },
        @{ Kind = 'hostfakesplit';      P = '';        R = '';           M = ''         },
        @{ Kind = 'fake+fakeddisorder'; P = 'midsld';  R = 'repeats=2';  M = ''         },
        @{ Kind = 'fake+syndata';       P = '';        R = '';           M = $topTlsMod }
    )

    $i = 0
    foreach ($p in $presets) {
        $i++
        $cmd = Build-ProviderCommand -Kind $p.Kind -SplitPos $p.P -Repeats $p.R -TlsMod $p.M
        Write-Host ("  [{0}] {1}" -f $i, $p.Kind) -ForegroundColor Yellow
        Write-Host ("      {0}" -f $cmd) -ForegroundColor White
        Write-Host ""
    }

    Write-Host "  Подсказка:" -ForegroundColor DarkCyan
    Write-Host "    • Запуск одной — пункт 12 (вставить вручную)" -ForegroundColor DarkGray
    Write-Host "    • Полный авто-подбор (только эти параметры) — пункт 10" -ForegroundColor DarkGray
    Write-Host "    • Дополнительные — пункт 24 (сохранит лучшие в providers.json)" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Enter..."
}

# ─────────────────────────────────────────────────────────────
#  Умный запуск под провайдера (пункт 24)
# ─────────────────────────────────────────────────────────────
function Invoke-SmartProviderRun {
    $ctx = Show-ProviderInfo
    if (-not $ctx) { return }

    Set-CurrentProviderProfile -ProfileName $ctx.Profile

    if ($ctx.Known.Count -gt 0) {
        Write-Host ""
        Write-Host ("  Найдено {0} рабочих стратегий для {1}:" -f $ctx.Known.Count, $ctx.Profile) -ForegroundColor Magenta
        $i = 0
        foreach ($s in $ctx.Known) {
            $i++
            $pct = if ($s.Total -gt 0) { [math]::Round($s.Score / $s.Total * 100, 0) } else { 0 }
            $short = if ($s.Cmd.Length -gt 90) { $s.Cmd.Substring(0, 87) + "..." } else { $s.Cmd }
            Write-Host ("    [{0}] [{1}/{2}] {3}%  {4}" -f $i, $s.Score, $s.Total, $pct, $short)
        }
        Write-Host ""
        Write-Host "  Действия:" -ForegroundColor DarkGray
        Write-Host "    <номер>  — запустить одну"
        Write-Host "    0        — отмена"
        Write-Host "    T        — запустить НОВЫЙ авто-подбор (перезаписать базу)"
        Write-Host ""
        Write-Host "  Выбор: " -NoNewline -ForegroundColor Magenta
        $sel = Read-Host

        if ($sel -match '^[TtТт]$') {
            # новый тест
        }
        elseif ($sel -eq '0' -or [string]::IsNullOrWhiteSpace($sel)) {
            return
        }
        else {
            $n = 0
            if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le $ctx.Known.Count) {
                Start-Zapret -StrategyLine $ctx.Known[$n - 1].Cmd
                return
            } else {
                Write-Log "Неверный номер" "ERR"
                return
            }
        }
    }

    Write-Host ""
    Write-Host ("  Применяю preset для {0}..." -f $ctx.Profile) -ForegroundColor Magenta
    Apply-ProviderPreset -ProfileName $ctx.Profile

    Write-Host ""
    Write-Host "  Запускаю авто-тест (ФОКУС на параметрах провайдера)..." -ForegroundColor Magenta

    $result = Invoke-StrategyScan

    if ($result -and $result.Count -gt 0) {
        $saved = 0
        foreach ($r in $result) {
            if ($r.Score -gt 0) {
                Save-ProviderStrategy -ProfileName $ctx.Profile -Strategy $r.Strategy `
                    -Score $r.Score -Total $r.Total
                $saved++
            }
        }
        Write-Log ("Сохранено в базу провайдера '{0}': {1} стратегий" -f $ctx.Profile, $saved) "INFO"
    }
}

function Clear-ProviderDb {
    $ctx = Show-ProviderInfo
    if (-not $ctx) { return }

    $db = Load-ProviderDb
    if (-not $db.Providers.$($ctx.Profile)) {
        Write-Log "Нет записей для '$($ctx.Profile)'" "WARN"
        return
    }

    Write-Host ""
    Write-Host ("  Удалить все сохранённые стратегии для '{0}'?" -f $ctx.Profile) -ForegroundColor Yellow
    $ans = Read-Host "  Введите 'yes' для подтверждения"
    if ($ans -ne 'yes') { return }

    $db.Providers.PSObject.Properties.Remove($ctx.Profile)
    Save-ProviderDb -Db $db
    Write-Log "База для '$($ctx.Profile)' очищена"
}

function Update-ProviderCache {
    $info = Get-ProviderInfo -Force
    if ($info.Err) {
        Write-Log "Не удалось обновить: $($info.Err)" "ERR"
    } else {
        Write-Log "Провайдер: $($info.ISP)  ($($info.City), $($info.ASN))"
        $profile = Find-ProviderProfile -IspName $info.ISP -Org $info.Org -ASN $info.ASN
        Set-CurrentProviderProfile -ProfileName $profile
    }
}