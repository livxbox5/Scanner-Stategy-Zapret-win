# ===============================================================
# === PROVIDER (Provider.ps1) — winws.exe / zapret1 ===
# ===============================================================
#  Умный подбор под провайдера: авто-детект ISP через ip-api.com,
#  встроенные presets, база найденных стратегий в config/providers.json.
#
#  Меню: пункты 21-24 (инфо, умный подбор, обновление, очистка).
#  Авто-подбор стратегии: пункт 28 в ZapretManager.ps1.
#
#  Актуально для zapret v1 (bol-van/zapret).
#  Добавлены IpId и расширенные Foolings (tcp_ts_up, datanoack).
# ===============================================================

$script:ProviderPresets = @{
    'Rostelecom' = @{
        Patterns  = @('Rostelecom','Ростелеком','Rt\.ru','Rostelecom PJSC')
        Methods   = @(
            'fake','split2','disorder2','multisplit','multidisorder',
            'fakedsplit','hostfakesplit','syndata'
        )
        SplitPos  = @('midsld','1','2','4')
        Foolings  = @('badseq','ts','badsum','md5sig','datanoack','tcp_ts_up')
        Autottls  = @('','2','4','8')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Ростелеком: fake + split2 с badseq; добавлен tcp_ts_up и IpId=seq'
    }
    'MTS' = @{
        Patterns  = @('MTS','МТС','Mobile TeleSystems','MTS PJSC')
        Methods   = @(
            'split2','multidisorder','disorder2','fake',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('2','midsld','1','4')
        Foolings  = @('ts','badseq','badsum','datanoack','tcp_ts_up')
        Autottls  = @('','2','4','8')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'МТС: split2 и multidisorder с ts; добавлен tcp_ts_up и IpId=seq'
    }
    'Beeline' = @{
        Patterns  = @('Beeline','Билайн','VimpelCom','Vimpel-Communications')
        Methods   = @(
            'multidisorder','split2','disorder','fake',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('midsld','2','4')
        Foolings  = @('md5sig','ts','badseq','datanoack','tcp_ts_up')
        Autottls  = @('','2','4')
        IpId      = @('rnd')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Билайн: multidisorder с md5sig; добавлен tcp_ts_up и IpId=rnd'
    }
    'Megafon' = @{
        Patterns  = @('Megafon','Мегафон','MegaFon','MegaFon PJSC')
        Methods   = @(
            'fakedsplit','split2','multisplit','fake',
            'hostfakesplit','syndata'
        )
        SplitPos  = @('1','midsld','2','4')
        Foolings  = @('badseq','ts','badsum','datanoack','tcp_ts_up')
        Autottls  = @('','4','8','2')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Мегафон: fakedsplit с badseq и autottl=4; добавлен tcp_ts_up и IpId=seq'
    }
    'ER-Telecom' = @{
        Patterns  = @('ER-Telecom','Дом\.ру','DOM\.RU','ER-Telecom Holding')
        Methods   = @(
            'split2','disorder2','multisplit',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('midsld','2','4')
        Foolings  = @('badsum','badseq','ts','datanoack','tcp_ts_up')
        Autottls  = @('','2','4')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Дом.ру: split2 и disorder2; добавлен tcp_ts_up и IpId=seq'
    }
    'TTK' = @{
        Patterns  = @('TTK','ТТК','TransTeleCom','TransTelecom')
        Methods   = @(
            'disorder2','split2','multidisorder',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('2','midsld','4')
        Foolings  = @('badseq','ts','badsum','datanoack','tcp_ts_up')
        Autottls  = @('','2','4')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'ТТК: disorder2 и split2; добавлен tcp_ts_up и IpId=seq'
    }
    'MGTS' = @{
        Patterns  = @('MGTS','МГТС','Moscow City Telephone')
        Methods   = @(
            'split2','disorder2','fake',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('1','midsld','2')
        Foolings  = @('ts','badseq','badsum','datanoack','tcp_ts_up')
        Autottls  = @('','2','4')
        IpId      = @('rnd')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'МГТС: split2 и disorder2; добавлен tcp_ts_up и IpId=rnd'
    }
    'Tele2' = @{
        Patterns  = @('Tele2','Теле2','Tele2 Russia')
        Methods   = @(
            'multisplit','split2','disorder2',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('2','midsld','1')
        Foolings  = @('ts','badseq','badsum','datanoack','tcp_ts_up')
        Autottls  = @('','2','4')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Tele2: multisplit; добавлен tcp_ts_up и IpId=seq'
    }
    'Yota' = @{
        Patterns  = @('Yota','Йота','Scartel')
        Methods   = @(
            'split2','disorder2','multisplit',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('midsld','2','4')
        Foolings  = @('badseq','ts','badsum','datanoack','tcp_ts_up')
        Autottls  = @('','2','4')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Yota: split2 с badseq; добавлен tcp_ts_up и IpId=seq'
    }
    'Tattelecom' = @{
        Patterns  = @('Tattelecom','Таттелеком')
        Methods   = @(
            'split2','disorder2','multidisorder',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('midsld','2','4')
        Foolings  = @('badseq','ts','md5sig','datanoack','tcp_ts_up')
        Autottls  = @('','2','4')
        IpId      = @('rnd')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Таттелеком: split2 и disorder2; добавлен tcp_ts_up и IpId=rnd'
    }
    'Ufanet' = @{
        Patterns  = @('Ufanet','Уфанет')
        Methods   = @(
            'split2','multisplit','disorder2',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('2','midsld','1')
        Foolings  = @('badseq','ts','badsum','datanoack','tcp_ts_up')
        Autottls  = @('','2','4')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Уфанет: split2 и multisplit; добавлен tcp_ts_up и IpId=seq'
    }
    'default' = @{
        Patterns  = @()
        Methods   = @(
            'fake','split2','disorder2','multisplit','multidisorder',
            'fakedsplit','hostfakesplit','syndata'
        )
        SplitPos  = @('1','2','4','midsld')
        Foolings  = @('ts','badseq','badsum','md5sig','datanoack','tcp_ts_up')
        Autottls  = @('','2','4','8')
        IpId      = @('seq')
        TcpFlagsSet   = @()
        TcpFlagsUnset = @()
        AnyProto      = 0
        Note      = 'Универсальный набор для zapret1; добавлен tcp_ts_up и IpId=seq'
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
    param([string]$IspName, [string]$ASN)

    if (-not $IspName) { return 'default' }

    $clean = $IspName -replace '(?i)(ООО|ОАО|ЗАО|ПАО|АО|LLC|Ltd|Inc|JSC|PJSC|LTD|LIMITED)\s*',''
    $clean = $clean -replace '[«»"''`]',''
    $clean = $clean.Trim()

    foreach ($key in $script:ProviderPresets.Keys) {
        if ($key -eq 'default') { continue }
        $p = $script:ProviderPresets[$key]
        foreach ($pattern in $p.Patterns) {
            if ($clean -match $pattern -or $IspName -match $pattern) {
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

function Apply-ProviderPreset {
    param([string]$ProfileName)

    $preset = Get-ProviderPreset -ProfileName $ProfileName

    $Global:ZapretState.Methods        = @($preset.Methods)
    $Global:ZapretState.SplitPositions = @($preset.SplitPos)
    $Global:ZapretState.Foolings       = @($preset.Foolings)
    $Global:ZapretState.Autottls       = @($preset.Autottls)
    $Global:ZapretState.TcpFlagsSet    = @($preset.TcpFlagsSet)
    $Global:ZapretState.TcpFlagsUnset  = @($preset.TcpFlagsUnset)
    $Global:ZapretState.AnyProtocol    = $preset.AnyProto

    # ─── Новые поля ───
    if ($preset.ContainsKey('IpId')) {
        $Global:ZapretState.IpId = @($preset.IpId)
    } else {
        $Global:ZapretState.IpId = @('seq')
    }

    Write-Host ("  Применён preset '{0}' (zapret1)" -f $ProfileName) -ForegroundColor Gray
    Write-Host ("    Methods  : {0}" -f ($preset.Methods  -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    SplitPos : {0}" -f ($preset.SplitPos -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Foolings : {0}" -f ($preset.Foolings -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Autottls : {0}" -f ($preset.Autottls -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    IpId     : {0}" -f ($Global:ZapretState.IpId -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Note     : {0}" -f $preset.Note) -ForegroundColor DarkYellow
}

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
        $db.Providers | Add-Member -NotePropertyName $ProfileName -NotePropertyValue @{
            ISP = $ProfileName
            Created = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            LastUpdate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            Strategies = @()
        } -Force
    }

    $entry = $db.Providers.$ProfileName
    $exists = $false
    foreach ($s in $entry.Strategies) {
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
        $entry.Strategies = @($entry.Strategies) + $newStrat
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
    Write-Host "  ─── ПРОВАЙДЕР ──────────────────────────────" -ForegroundColor DarkCyan

    $info = Get-ProviderInfo
    if ($info.Err) {
        Write-Host ("  [!] Не удалось определить: {0}" -f $info.Err) -ForegroundColor Yellow
        Write-Host "  ────────────────────────────────────────────" -ForegroundColor DarkCyan
        return $null
    }

    $profile = Find-ProviderProfile -IspName $info.ISP -ASN $info.ASN

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
    Write-Host "  ────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host ""

    return [pscustomobject]@{
        Info    = $info
        Profile = $profile
        Known   = $known
    }
}

function Invoke-SmartProviderRun {
    $ctx = Show-ProviderInfo
    if (-not $ctx) { return }

    if ($ctx.Known.Count -gt 0) {
        Write-Host ""
        Write-Host ("  Найдено {0} рабочих стратегий для {1}:" -f $ctx.Known.Count, $ctx.Profile) -ForegroundColor Cyan
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
        Write-Host "  Выбор: " -NoNewline -ForegroundColor Cyan
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
    Write-Host ("  Применяю preset для {0}..." -f $ctx.Profile) -ForegroundColor Cyan
    Apply-ProviderPreset -ProfileName $ctx.Profile

    Write-Host ""
    Write-Host "  Запускаю авто-тест..." -ForegroundColor Cyan

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
        $profile = Find-ProviderProfile -IspName $info.ISP -ASN $info.ASN
        Set-CurrentProviderProfile -ProfileName $profile
    }
}

# ═════════════════════════════════════════════════════════════
#  АВТО-ПОДБОР СТРАТЕГИИ (без blockcheck) — zapret1
# ═════════════════════════════════════════════════════════════
#  Использует New-StrategyCandidates и Test-Strategy из StrategyTester.ps1.
#
#  Алгоритм:
#    1. Проверяет уже известные рабочие стратегии из базы (если не -SkipKnown).
#    2. Генерирует кандидатов через New-StrategyCandidates.
#    3. Ограничивает количество (по умолчанию 50) и перемешивает.
#    4. По очереди тестирует каждую на доменах.
#    5. Сохраняет все успешные в базу провайдера.
#    6. Возвращает лучшую.
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

    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       АВТО-ПОДБОР СТРАТЕГИИ (zapret1, без blockcheck)   ║" -ForegroundColor Cyan
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

    # ─── Шаг 1: Проверка известных стратегий ───
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

    # ─── Шаг 2: Генерация кандидатов ───
    Write-Host "  Генерация стратегий-кандидатов..." -ForegroundColor DarkCyan
    $candidates = @(New-StrategyCandidates)
    if ($candidates.Count -eq 0) {
        Write-Log "Нет кандидатов для тестирования" "ERR"
        Read-Host "  Enter..."; return $null
    }
    Write-Host ("  Всего сгенерировано: {0}" -f $candidates.Count) -ForegroundColor Gray

    # ─── Шаг 3: Ограничение и перемешивание ───
    if ($candidates.Count -gt $MaxStrategies) {
        $candidates = @($candidates | Get-Random -Count $MaxStrategies)
        Write-Host ("  Ограничено до: {0}" -f $MaxStrategies) -ForegroundColor Yellow
    }
    Write-Host ""

    # ─── Шаг 4: Перебор ───
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

    # ─── Шаг 5: Итоги ───
    Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║                      ИТОГИ                             ║" -ForegroundColor Magenta
    Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ("  Время:          {0} мин" -f $totalTime) -ForegroundColor Gray
    Write-Host ("  Проверено:      {0}" -f $i) -ForegroundColor Gray
    Write-Host ("  Успешных:       {0}" -f $results.Count) -ForegroundColor $(if ($results.Count -gt 0) { "Green" } else { "Red" })
    Write-Host ""

    if ($results.Count -eq 0) {
        Write-Log "Ни одна стратегия не дала положительного результата." "WARN"
        Read-Host "  Enter..."
        return $null
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

    # ─── Отчёт ───
    try {
        $repDir = Join-Path (Split-Path $Global:ZapretState.ConfigFile -Parent) '..\resultats'
        $repDir = [System.IO.Path]::GetFullPath($repDir)
        if (-not (Test-Path $repDir)) { New-Item -ItemType Directory -Path $repDir -Force | Out-Null }
        $repFile = Join-Path $repDir 'auto_find_zapret1.txt'

        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("# ═══════════════════════════════════════════════════════════════")
        [void]$sb.AppendLine("# Auto-Strategy-Find (zapret1 / winws.exe)")
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