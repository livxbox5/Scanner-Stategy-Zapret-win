# ===============================================================
# === PROVIDER (Provider.ps1) — winws2.exe / zapret2 ===
# ===============================================================
#  Авто-детект ISP через ip-api.com, встроенные presets,
#  база найденных стратегий в config/providers.json.
#  Фокус-режим: генерация только под текущего провайдера.
#
#  Меню: пункты 21-24.
#  Авто-подбор стратегии: пункт 28 в ZapretManager2.ps1.
#
#  Актуально для zapret2 (bol-van/zapret2, v0.9.5+).
#  Добавлены новые blob-файлы и методы (QUIC, TLS, HTTP).
# ===============================================================

$script:ProviderPresets = @{

    'Rostelecom' = @{
        Patterns   = @('Rostelecom','Ростелеком','Rt\.ru','Rostelecom PJSC',
                       'Macroregional Branch South','Karachaevo-Cherkess')
        LuaMethods = @('fake','multisplit','multidisorder','fakeddisorder','hostfakesplit','syndata',
                       'tls_client_hello_clone','oob','rst','rstack','tcpseg')
        Splits     = @('1','2','midsld','sniext+1','host','host+1','endhost')
        Repeats    = @('repeats=2','repeats=4','repeats=6')
        TlsMods    = @('rnd','rnd,rndsni','rnd,dupsid','sni=www.google.com')
        BlobFiles  = @(
            'tls_clienthello_www_google_com.bin',
            'tls_clienthello_max_ru.bin',
            'quic_initial_rutube_ru.bin',
            'quic_initial_rutracker_org.bin',
            'quic_initial_facebook_com_quiche.bin',
            'tls_clienthello_vk_com.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_google, quic_rutube, quic_rutracker, quic_facebook_quiche, tls_vk'
        Note       = 'Ростелеком (в т.ч. Юг): fake + multisplit, добавлены QUIC/TLS blob-файлы и новые методы'
    }

    'MTS' = @{
        Patterns   = @('MTS','МТС','Mobile TeleSystems','MTS PJSC')
        LuaMethods = @('fake','multisplit','multidisorder','fakeddisorder','hostfakesplit','syndata',
                       'oob','tcpseg','http_hostcase','http_domcase')
        Splits     = @('1','2','midsld','sniext+1')
        Repeats    = @('repeats=4','repeats=6','repeats=8')
        TlsMods    = @('rnd,rndsni','rnd,dupsid,rndsni','sni=www.google.com')
        BlobFiles  = @(
            'tls_clienthello_www_google_com.bin',
            'quic_initial_www_google_com.bin',
            'quic_initial_facebook_com.bin',
            'tls_clienthello_vk_com.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_google, quic_google, quic_facebook, tls_vk'
        Note       = 'МТС: fake + multidisorder, добавлены HTTP-методы и QUIC blob-файлы'
    }

    'Beeline' = @{
        Patterns   = @('Beeline','Билайн','VimpelCom','Vimpel-Communications')
        LuaMethods = @('fake','multidisorder','multisplit','fakeddisorder','hostfakesplit','syndata',
                       'tls_client_hello_clone','oob','rst')
        Splits     = @('1','2','midsld','host')
        Repeats    = @('repeats=4','repeats=6')
        TlsMods    = @('rnd,dupsid','rnd,rndsni')
        BlobFiles  = @(
            'tls_clienthello_4pda_to.bin',
            'quic_initial_4pda_to.bin',
            'quic_initial_rutracker_org.bin',
            'tls_clienthello_vk_com.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_4pda, quic_4pda, quic_rutracker, tls_vk'
        Note       = 'Билайн: multidisorder с tls_mod=rnd,dupsid; добавлены QUIC/TLS blob-файлы'
    }

    'Megafon' = @{
        Patterns   = @('Megafon','Мегафон','MegaFon','MegaFon PJSC')
        LuaMethods = @('fake','multisplit','fakeddisorder','hostfakesplit','syndata',
                       'oob','tcpseg','http_methodeol','http_unixeol')
        Splits     = @('1','2','midsld','sniext+1')
        Repeats    = @('repeats=2','repeats=4','repeats=6')
        TlsMods    = @('sni=www.google.com','rnd,rndsni')
        BlobFiles  = @(
            'tls_clienthello_5ka_ru.bin',
            'quic_initial_5ka_ru.bin',
            'quic_initial_facebook_com.bin',
            'tls_clienthello_max_ru.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_5ka, quic_5ka, quic_facebook, tls_max'
        Note       = 'Мегафон: fake + fakeddisorder, добавлены HTTP EOL-методы и QUIC blob-файлы'
    }

    'ER-Telecom' = @{
        Patterns   = @('ER-Telecom','Дом\.ру','DOM\.RU','ER-Telecom Holding')
        LuaMethods = @('fake','multisplit','multidisorder','hostfakesplit',
                       'tls_client_hello_clone','rst','rstack','http_hostcase')
        Splits     = @('1','sniext+1','midsld')
        Repeats    = @('repeats=2','repeats=4')
        TlsMods    = @('rnd','rnd,rndsni')
        BlobFiles  = @(
            'tls_clienthello_max_ru.bin',
            'quic_initial_tencent_com.bin',
            'quic_initial_rutracker_org.bin',
            'tls_clienthello_vk_com.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_max, quic_tencent, quic_rutracker, tls_vk'
        Note       = 'Дом.ру: fake + multisplit, добавлены QUIC/TLS blob-файлы и новые методы'
    }

    'TTK' = @{
        Patterns   = @('TTK','ТТК','TransTeleCom','TransTelecom')
        LuaMethods = @('fake','multidisorder','multisplit','fakeddisorder',
                       'oob','tcpseg','http_domcase')
        Splits     = @('1','2','midsld')
        Repeats    = @('repeats=4','repeats=6')
        TlsMods    = @('rnd','rnd,rndsni')
        BlobFiles  = @(
            'tls_clienthello_www_sferum_ru.bin',
            'quic_initial_facebook_com.bin',
            'tls_clienthello_vk_com.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_sferum, quic_facebook, tls_vk'
        Note       = 'ТТК: fake + multidisorder, добавлены новые методы и blob-файлы'
    }

    'MGTS' = @{
        Patterns   = @('MGTS','МГТС','Moscow City Telephone')
        LuaMethods = @('fake','multisplit','fakeddisorder','hostfakesplit',
                       'http_hostcase','http_domcase','http_methodeol')
        Splits     = @('midsld','1','2')
        Repeats    = @('repeats=2','repeats=4')
        TlsMods    = @('rnd,rndsni')
        BlobFiles  = @(
            'tls_clienthello_www_google_com.bin',
            'quic_initial_www_google_com.bin',
            'quic_initial_rutracker_org.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_google, quic_google, quic_rutracker'
        Note       = 'МГТС: fake + multisplit, добавлены HTTP-методы и QUIC blob-файлы'
    }

    'Tele2' = @{
        Patterns   = @('Tele2','Теле2','Tele2 Russia')
        LuaMethods = @('fake','multisplit','multidisorder','hostfakesplit',
                       'tls_client_hello_clone','rst')
        Splits     = @('1','2','midsld')
        Repeats    = @('repeats=2','repeats=4')
        TlsMods    = @('rnd','rnd,rndsni')
        BlobFiles  = @(
            'quic_initial_steamcommunity_com.bin',
            'quic_initial_facebook_com.bin',
            'tls_clienthello_vk_com.bin'
        )
        Fool       = @()
        BlobHint   = 'quic_steam, quic_facebook, tls_vk'
        Note       = 'Tele2: fake + multisplit, добавлены QUIC/TLS blob-файлы'
    }

    'Yota' = @{
        Patterns   = @('Yota','Йота','Scartel')
        LuaMethods = @('fake','multisplit','fakeddisorder','hostfakesplit','syndata',
                       'oob','tcpseg','http_unixeol')
        Splits     = @('sniext+1','1','midsld')
        Repeats    = @('repeats=2','repeats=4')
        TlsMods    = @('rnd,rndsni')
        BlobFiles  = @(
            'tls_clienthello_4pda_to.bin',
            'quic_initial_4pda_to.bin',
            'quic_initial_rutracker_org.bin'
        )
        Fool       = @()
        BlobHint   = 'tls_4pda, quic_4pda, quic_rutracker'
        Note       = 'Yota: fake + fakeddisorder, добавлены новые методы и QUIC blob-файлы'
    }

    'default' = @{
        Patterns   = @()
        LuaMethods = @('fake','multisplit','multidisorder','fakeddisorder','hostfakesplit','syndata',
                       'tls_client_hello_clone','rst','rstack','oob','tcpseg',
                       'http_hostcase','http_domcase','http_methodeol','http_unixeol')
        Splits     = @('1','2','midsld','sniext+1','host','host+1','endhost','endhost-1',
                       'midsld-2','midsld+2','method+2',
                       '1,sniext+1,host+1,midsld-2,midsld,midsld+2,endhost-1')
        Repeats    = @('repeats=1','repeats=2','repeats=4','repeats=6','repeats=8')
        TlsMods    = @('rnd','rnd,rndsni','rnd,dupsid','rnd,dupsid,rndsni',
                       'sni=www.google.com','sni=ya.ru')
        BlobFiles  = @()
        Fool       = @()
        BlobHint   = 'fake_default_tls, fake_default_quic'
        Note       = 'Универсальный набор: полный перебор методов, включая новые (oob, tcpseg, rst, HTTP-методы) и все blob-файлы'
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

function Set-CurrentProviderProfile {
    param([string]$ProfileName)
    if (-not $ProfileName) { return }
    if ($Global:ZapretState.ProviderProfile -ne $ProfileName) {
        $Global:ZapretState.ProviderProfile = $ProfileName
        Save-Settings
    }
}

function Get-ProviderFocusParams {
    $profile = $Global:ZapretState.ProviderProfile
    if (-not $profile) { return $null }
    if ($profile -eq 'default') { return $null }
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
    $empty = [pscustomobject]@{ Version = 1; Providers = [pscustomobject]@{} }
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
    } catch { return $empty }
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

function Build-ProviderCommand {
    param(
        [ValidateSet('fake+multisplit','fake+multidisorder','fake+fakeddisorder','hostfakesplit','fake+syndata','tls_client_hello_clone','rst+rstack')]
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

    $blobDefs = Get-Winws2BlobDefs

    $hl = ""
    $he = ""
    if ($Global:ZapretState.TxtPath -and (Test-Path $Global:ZapretState.TxtPath)) {
        $name = $Global:ZapretState.Hostlist
        if (-not $name) { $name = 'list-general.txt' }
        $f = Join-Path $Global:ZapretState.TxtPath $name
        if (Test-Path $f) { $hl = " --hostlist=`"$($f -replace '\\','/')`"" }

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
            "--filter-tcp=443 --filter-l7=tls$hl --payload=tls_client_hello " +
            "--lua-desync=fake:blob=$blobKey`:tls_mod=$TlsMod`:$Repeats$foolSuf " +
            "--lua-desync=multisplit`:pos=$SplitPos$foolSuf"
        }
        'fake+multidisorder' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=tls_client_hello " +
            "--lua-desync=fake:blob=$blobKey`:$Repeats$foolSuf " +
            "--lua-desync=multidisorder`:pos=$SplitPos$foolSuf"
        }
        'fake+fakeddisorder' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=tls_client_hello " +
            "--lua-desync=fake:blob=$blobKey`:repeats=2$foolSuf " +
            "--lua-desync=fakeddisorder`:pos=$SplitPos$foolSuf"
        }
        'hostfakesplit' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=tls_client_hello " +
            "--lua-desync=hostfakesplit`:host=www.google.com`:midhost=host-2`:altorder=1`:disorder_after$foolSuf"
        }
        'fake+syndata' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=tls_client_hello " +
            "--lua-desync=syndata`:blob=$blobKey$foolSuf " +
            "--lua-desync=multisplit`:pos=1,sld+1,endsld-2`:seqovl=1$foolSuf"
        }
        'tls_client_hello_clone' {
            "--filter-tcp=443 --filter-l7=tls$hl --payload=tls_client_hello " +
            "--lua-desync=tls_client_hello_clone:blob=cloned_tls:fallback=fake_default_tls " +
            "--lua-desync=fake:blob=cloned_tls:optional:tcp_seq=10000000:tls_mod=rnd,dupsid,sni=fonts.google.com$foolSuf"
        }
        'rst+rstack' {
            "--filter-tcp=443$hl --lua-desync=rst:rstack$foolSuf"
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
        Write-Host "  Для default-профиля используй пункт 10 (АВТО-ТЕСТ)." -ForegroundColor Yellow
        Read-Host "  Enter..."; return
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
        @{ Kind = 'fake+multisplit';         P = $topSplit; R = $topRepeats;  M = $topTlsMod },
        @{ Kind = 'fake+multidisorder';      P = $topSplit; R = $topRepeats;  M = $topTlsMod },
        @{ Kind = 'hostfakesplit';           P = '';        R = '';           M = ''         },
        @{ Kind = 'fake+fakeddisorder';      P = 'midsld';  R = 'repeats=2';  M = ''         },
        @{ Kind = 'fake+syndata';            P = '';        R = '';           M = $topTlsMod },
        @{ Kind = 'tls_client_hello_clone';  P = '';        R = '';           M = ''         },
        @{ Kind = 'rst+rstack';              P = '';        R = '';           M = ''         }
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
                Write-Log "Неверный номер" "ERR"; return
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
        Write-Log "Нет записей для '$($ctx.Profile)'" "WARN"; return
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

# ═════════════════════════════════════════════════════════════
#  АВТО-ПОДБОР СТРАТЕГИИ (без blockcheck) — zapret2
# ═════════════════════════════════════════════════════════════
#  Использует New-Winws2StrategyCandidates и Test-Strategy из winws2.ps1.
#  Работает только если winws2 готов (Test-Winws2Ready).
# ═════════════════════════════════════════════════════════════

function Get-AutoTestDomains {
    param([string[]]$Override = @())
    if ($Override -and $Override.Count -gt 0) { return $Override }

    $defaults = @(
        'https://www.youtube.com',
        'https://discord.com',
        'https://www.google.com',
        'https://web.telegram.org'
    )

    try {
        if (Get-Command Get-DomainsFromHostlist -ErrorAction SilentlyContinue) {
            $hl = @(Get-DomainsFromHostlist -Max 200)
            if ($hl.Count -gt 0) {
                $blocked = @()
                foreach ($u in $hl) {
                    $r = Test-Endpoint -Url $u -TimeoutSec 3
                    if (-not $r.Ok) { $blocked += $u }
                    if ($blocked.Count -ge 6) { break }
                }
                if ($blocked.Count -ge 3) { return $blocked }
            }
        }
    } catch { }

    return $defaults
}

function Invoke-AutoStrategyFind {
    param(
        [string]$ProfileName = $Global:ZapretState.ProviderProfile,
        [string[]]$TestDomains = @(),
        [int]$MaxStrategies = 50,
        [switch]$SkipKnown
    )

    if (-not (Test-Admin)) {
        Write-Log "Нужны права администратора" "ERR"; return $null
    }

    $ready = Test-Winws2Ready
    if (-not $ready.Ready) {
        Write-Log "winws2 не готов:" "ERR"
        $ready.Issues | ForEach-Object { Write-Log "  - $_" "ERR" }
        Read-Host "  Enter..."; return $null
    }

    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       АВТО-ПОДБОР СТРАТЕГИИ (zapret2, без blockcheck)   ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $ctx = Show-ProviderInfo
    if ($ctx) {
        if (-not $ProfileName) { $ProfileName = $ctx.Profile }
        Write-Host ("  Профиль для сохранения: {0}" -f $ProfileName) -ForegroundColor Green
    }
    if (-not $ProfileName) { $ProfileName = 'default' }

    if (-not $TestDomains -or $TestDomains.Count -eq 0) {
        Write-Host "  Подбираю тестовые домены..." -ForegroundColor DarkGray
        $TestDomains = @(Get-AutoTestDomains)
    }

    Write-Host ("  Тестовых доменов: {0}" -f $TestDomains.Count) -ForegroundColor Gray
    foreach ($d in $TestDomains) {
        Write-Host ("    • {0}" -f $d) -ForegroundColor DarkGray
    }
    Write-Host ""

    # ─── Шаг 1: Проверка известных ───
    if (-not $SkipKnown) {
        $known = @(Get-KnownStrategies -ProfileName $ProfileName)
        if ($known.Count -gt 0) {
            Write-Host ("  ─── Проверка {0} известных стратегий ────────────────" -f $known.Count) -ForegroundColor DarkCyan
            $ki = 0
            foreach ($s in $known) {
                $ki++
                Write-Host ("    [{0}/{1}] проверяю..." -f $ki, $known.Count) -ForegroundColor DarkGray
                $r = Test-Strategy -StrategyLine $s.Cmd -Domains $TestDomains -Quiet
                if ($r -and $r.Score -gt 0) {
                    $pct = [math]::Round($r.Score / $r.Total * 100, 1)
                    Write-Host ("        работает: {0}/{1} ({2}%)" -f $r.Score, $r.Total, $pct) -ForegroundColor Green
                    if ($r.Score -eq $r.Total) {
                        Write-Host "        [OK] Известная стратегия работает идеально!" -ForegroundColor Green
                        Write-Host ""
                        Save-ProviderStrategy -ProfileName $ProfileName `
                            -Strategy $s.Cmd -Score $r.Score -Total $r.Total
                        Write-Host ("  {0}" -f $s.Cmd) -ForegroundColor White
                        Write-Host ""
                        Read-Host "  Enter..."
                        return [pscustomobject]@{ Method = "known"; Line = $s.Cmd; Score = $r.Score; Total = $r.Total }
                    }
                }
            }
            Write-Host ""
        }
    }

    # ─── Шаг 1.5: Проверка найденных в интернете ───
    if (Get-Command Get-DiscoveredStrategies -ErrorAction SilentlyContinue) {
        $discovered = @(Get-DiscoveredStrategies -UntestedOnly -Max 20 -Engine 'winws2')
        if ($discovered.Count -gt 0) {
            Write-Host ""
            Write-Host ("  ─── Проверка {0} найденных в интернете ─────────────" -f $discovered.Count) -ForegroundColor DarkCyan
            $di = 0
            foreach ($d in $discovered) {
                $di++
                Write-Host ("    [{0}/{1}] {2}" -f $di, $discovered.Count, `
                    $(if ($d.Candidate.Length -gt 90) { $d.Candidate.Substring(0,87) + "..." } else { $d.Candidate })) `
                    -ForegroundColor DarkGray

                $lineToTest = $d.Candidate
                if ($d.Completeness -like '*fragment*' -and (Get-Command Add-Winws2Prelude -ErrorAction SilentlyContinue)) {
                    $lineToTest = Add-Winws2Prelude -Line $lineToTest
                }

                $r = Test-Strategy -StrategyLine $lineToTest -Domains $TestDomains -Quiet
                if ($r -and $r.Score -gt 0) {
                    $pct = [math]::Round($r.Score / $r.Total * 100, 1)
                    Write-Host ("        работает: {0}/{1} ({2}%)" -f $r.Score, $r.Total, $pct) -ForegroundColor Green

                    Update-DiscoveredStrategyScore -Candidate $d.Candidate -Score $r.Score -Total $r.Total

                    Save-ProviderStrategy -ProfileName $ProfileName `
                        -Strategy $lineToTest -Score $r.Score -Total $r.Total

                    if ($r.Score -eq $r.Total) {
                        Write-Host "        [OK] Интернет-стратегия работает идеально!" -ForegroundColor Green
                        Write-Host ""
                        Write-Host ("  {0}" -f $lineToTest) -ForegroundColor White
                        Write-Host ""
                        Read-Host "  Enter..."
                        return [pscustomobject]@{ Method = "discovered"; Line = $lineToTest; Score = $r.Score; Total = $r.Total }
                    }
                } else {
                    Update-DiscoveredStrategyScore -Candidate $d.Candidate -Score 0 -Total $(if ($r) { $r.Total } else { 0 })
                }
            }
            Write-Host ""
        }
    }

    # ─── Шаг 2: Генерация ───
    Write-Host "  Генерация Lua-стратегий..." -ForegroundColor DarkCyan
    $candidates = @(New-Winws2StrategyCandidates)
    if ($candidates.Count -eq 0) {
        Write-Log "Нет кандидатов для тестирования" "ERR"
        Read-Host "  Enter..."; return $null
    }
    Write-Host ("  Всего сгенерировано: {0}" -f $candidates.Count) -ForegroundColor Gray

    if ($candidates.Count -gt $MaxStrategies) {
        $candidates = @($candidates | Get-Random -Count $MaxStrategies)
        Write-Host ("  Ограничено до: {0}" -f $MaxStrategies) -ForegroundColor Yellow
    }
    Write-Host ""

    # ─── Шаг 3: Перебор ───
    $results = New-Object System.Collections.Generic.List[object]
    $bestStrategy = $null
    $bestScore = -1
    $startTime = Get-Date
    $i = 0

    Write-Host "  ─── Перебор ──────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""

    foreach ($c in $candidates) {
        $i++
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $eta = if ($i -gt 1) {
            [math]::Round(($elapsed / ($i - 1)) * ($candidates.Count - $i + 1) / 60, 1)
        } else { '?' }

        Write-Host ("  [{0,3}/{1}] ETA {2} мин  " -f $i, $candidates.Count, $eta) -ForegroundColor DarkCyan -NoNewline
        $methodShort = if ($c.Method.Length -gt 70) { $c.Method.Substring(0, 67) + '...' } else { $c.Method }
        Write-Host $methodShort -ForegroundColor White

        $result = Test-Strategy -StrategyLine $c.Line -Domains $TestDomains -Quiet
        if ($null -eq $result) { continue }

        $pct = if ($result.Total -gt 0) { [math]::Round($result.Score / $result.Total * 100, 1) } else { 0 }
        $color = if ($pct -eq 100) { 'Green' }
                 elseif ($pct -ge 75) { 'Yellow' }
                 elseif ($pct -gt 0) { 'DarkYellow' }
                 else { 'DarkGray' }
        Write-Host ("        Результат: {0}/{1} ({2}%)" -f $result.Score, $result.Total, $pct) -ForegroundColor $color

        if ($result.Score -gt 0) {
            $results.Add([pscustomobject]@{
                Method = $c.Method; Line = $c.Line
                Score = $result.Score; Total = $result.Total; Pct = $pct
            }) | Out-Null

            Save-ProviderStrategy -ProfileName $ProfileName `
                -Strategy $c.Line -Score $result.Score -Total $result.Total

            if ($result.Score -gt $bestScore) {
                $bestScore = $result.Score
                $bestStrategy = $c
            }

            if ($result.Score -eq $result.Total) {
                Write-Host "        [OK] Идеальная стратегия найдена — выходим." -ForegroundColor Green
                break
            }
        }
    }

    $totalTime = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    Write-Host ""

    # ─── Шаг 4: Итоги ───
    Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║                      ИТОГИ                             ║" -ForegroundColor Magenta
    Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ("  Время:          {0} мин" -f $totalTime) -ForegroundColor Gray
    Write-Host ("  Проверено:      {0}" -f $i) -ForegroundColor Gray
    Write-Host ("  Успешных:       {0}" -f $results.Count) -ForegroundColor $(if ($results.Count -gt 0) { "Green" } else { "Red" })
    Write-Host ""

    if ($results.Count -eq 0) {
        Write-Log "Ни одна стратегия не дала положительного результата." "WARN"
        Read-Host "  Enter..."; return $null
    }

    $top = @($results | Sort-Object -Property @{Expression='Score';Descending=$true} | Select-Object -First 5)
    Write-Host "  ─── ТОП-5 РАБОЧИХ ────────────────────────────────────" -ForegroundColor Green
    $ri = 0
    foreach ($r in $top) {
        $ri++
        $col = if ($r.Pct -eq 100) { "Green" } elseif ($r.Pct -ge 75) { "Yellow" } else { "White" }
        Write-Host ("  [{0}] [{1}/{2}] {3,5}%   {4}" -f $ri, $r.Score, $r.Total, $r.Pct, $r.Method) -ForegroundColor $col
        $short = if ($r.Line.Length -gt 120) { $r.Line.Substring(0, 117) + '...' } else { $r.Line }
        Write-Host ("      {0}" -f $short) -ForegroundColor DarkGray
    }
    Write-Host ""

    if ($bestStrategy) {
        Write-Host "  ─── ЛУЧШАЯ СТРАТЕГИЯ ────────────────────────────────" -ForegroundColor Green
        Write-Host ("  Оценка: {0}/{1}" -f $bestScore, $TestDomains.Count) -ForegroundColor Green
        Write-Host ("  Строка: {0}" -f $bestStrategy.Line) -ForegroundColor White
        Write-Host ""
    }

    try {
        $repDir = Join-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) '..\resultats'
        $repDir = [System.IO.Path]::GetFullPath($repDir)
        if (-not (Test-Path $repDir)) { New-Item -ItemType Directory -Path $repDir -Force | Out-Null }
        $repFile = Join-Path $repDir 'auto_find_zapret2.txt'

        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("# ═══════════════════════════════════════════════════════════════")
        [void]$sb.AppendLine("# Auto-Strategy-Find (zapret2 / winws2.exe)")
        [void]$sb.AppendLine("# Дата:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine("# Профиль:  $ProfileName")
        [void]$sb.AppendLine("# Время:    $totalTime мин")
        [void]$sb.AppendLine("# Проверено: $i")
        [void]$sb.AppendLine("# Успешных: $($results.Count)")
        [void]$sb.AppendLine("# Домены:   $($TestDomains -join ', ')")
        [void]$sb.AppendLine("# ═══════════════════════════════════════════════════════════════")
        [void]$sb.AppendLine("")
        $ri = 0
        foreach ($r in $top) {
            $ri++
            [void]$sb.AppendLine(("# [{0}] [{1}/{2}] {3}%   {4}" -f $ri, $r.Score, $r.Total, $r.Pct, $r.Method))
            [void]$sb.AppendLine("--new")
            [void]$sb.AppendLine($r.Line)
            [void]$sb.AppendLine("")
        }
        Set-Content -Path $repFile -Value $sb.ToString() -Encoding UTF8
        Write-Host ("  Отчёт: {0}" -f $repFile) -ForegroundColor Green
    } catch { }

    Write-Host ""
    Write-Host "  Запустить лучшую сейчас? (Y/N): " -NoNewline -ForegroundColor Cyan
    $ans = Read-Host
    if ($ans -match '^[YyДд]' -and $bestStrategy) {
        Start-Zapret -StrategyLine $bestStrategy.Line
    } else {
        Read-Host "  Enter..."
    }

    return [pscustomobject]@{
        Method = if ($bestStrategy) { $bestStrategy.Method } else { "" }
        Line   = if ($bestStrategy) { $bestStrategy.Line   } else { "" }
        Score  = $bestScore
        Total  = $TestDomains.Count
    }
}