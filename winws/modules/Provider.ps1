# ===============================================================
# === PROVIDER (Provider.ps1) ===
# ===============================================================
#  Умный подбор под провайдера: авто-детект ISP через ip-api.com,
#  встроенные presets, база найденных стратегий в config/providers.json.
#  Меню: пункты 21-24.
#
#  v2:
#    - 'Rostelecom' и 'default' расширены fakedsplit/hostfakesplit/syndata
#    - 'Rt.ru' → 'Rt\.ru' (экранирование точки в regex)
#    - удалён дубль комментария в шапке
# ===============================================================

$script:ProviderPresets = @{
    'Rostelecom' = @{
        Patterns  = @('Rostelecom','Ростелеком','Rt\.ru','Rostelecom PJSC')
        Methods   = @(
            'fake','split2','disorder2','multisplit','multidisorder',
            'fakedsplit','hostfakesplit','syndata'
        )
        SplitPos  = @('midsld','1','2','4')
        Foolings  = @('badseq','ts','badsum','md5sig')
        Autottls  = @('','2','4','8')
        Note      = 'Ростелеком: fake / split2 с badseq; проверяем fakedsplit, hostfakesplit, syndata'
    }
    'MTS' = @{
        Patterns  = @('MTS','МТС','Mobile TeleSystems','MTS PJSC')
        Methods   = @(
            'split2','multidisorder','disorder2','fake',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('2','midsld','1','4')
        Foolings  = @('ts','badseq','badsum')
        Autottls  = @('','2','4','8')
        Note      = 'МТС: split2 и multidisorder с ts'
    }
    'Beeline' = @{
        Patterns  = @('Beeline','Билайн','VimpelCom','Vimpel-Communications')
        Methods   = @(
            'multidisorder','split2','disorder','fake',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('midsld','2','4')
        Foolings  = @('md5sig','ts','badseq')
        Autottls  = @('','2','4')
        Note      = 'Билайн: multidisorder с md5sig'
    }
    'Megafon' = @{
        Patterns  = @('Megafon','Мегафон','MegaFon','MegaFon PJSC')
        Methods   = @(
            'fakedsplit','split2','multisplit','fake',
            'hostfakesplit','syndata'
        )
        SplitPos  = @('1','midsld','2','4')
        Foolings  = @('badseq','ts','badsum')
        Autottls  = @('','4','8','2')
        Note      = 'Мегафон: fakedsplit с badseq и autottl=4'
    }
    'ER-Telecom' = @{
        Patterns  = @('ER-Telecom','Дом\.ру','DOM\.RU','ER-Telecom Holding')
        Methods   = @(
            'split2','disorder2','multisplit',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('midsld','2','4')
        Foolings  = @('badsum','badseq','ts')
        Autottls  = @('','2','4')
        Note      = 'Дом.ру: split2 и disorder2'
    }
    'TTK' = @{
        Patterns  = @('TTK','ТТК','TransTeleCom','TransTelecom')
        Methods   = @(
            'disorder2','split2','multidisorder',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('2','midsld','4')
        Foolings  = @('badseq','ts','badsum')
        Autottls  = @('','2','4')
        Note      = 'ТТК: disorder2 и split2'
    }
    'MGTS' = @{
        Patterns  = @('MGTS','МГТС','Moscow City Telephone')
        Methods   = @(
            'split2','disorder2','fake',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('1','midsld','2')
        Foolings  = @('ts','badseq','badsum')
        Autottls  = @('','2','4')
        Note      = 'МГТС: split2 и disorder2'
    }
    'Tele2' = @{
        Patterns  = @('Tele2','Теле2','Tele2 Russia')
        Methods   = @(
            'multisplit','split2','disorder2',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('2','midsld','1')
        Foolings  = @('ts','badseq','badsum')
        Autottls  = @('','2','4')
        Note      = 'Tele2: multisplit'
    }
    'Yota' = @{
        Patterns  = @('Yota','Йота','Scartel')
        Methods   = @(
            'split2','disorder2','multisplit',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('midsld','2','4')
        Foolings  = @('badseq','ts','badsum')
        Autottls  = @('','2','4')
        Note      = 'Yota: split2 с badseq'
    }
    'Tattelecom' = @{
        Patterns  = @('Tattelecom','Таттелеком')
        Methods   = @(
            'split2','disorder2','multidisorder',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('midsld','2','4')
        Foolings  = @('badseq','ts','md5sig')
        Autottls  = @('','2','4')
        Note      = 'Таттелеком: split2 и disorder2'
    }
    'Ufanet' = @{
        Patterns  = @('Ufanet','Уфанет')
        Methods   = @(
            'split2','multisplit','disorder2',
            'fakedsplit','hostfakesplit'
        )
        SplitPos  = @('2','midsld','1')
        Foolings  = @('badseq','ts','badsum')
        Autottls  = @('','2','4')
        Note      = 'Уфанет: split2 и multisplit'
    }
    'default' = @{
        Patterns  = @()
        Methods   = @(
            'fake','split2','disorder2','multisplit','multidisorder',
            'fakedsplit','hostfakesplit','syndata'
        )
        SplitPos  = @('1','2','4','midsld')
        Foolings  = @('ts','badseq','badsum','md5sig')
        Autottls  = @('','2','4','8')
        Note      = 'Универсальный набор'
    }
}

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

    Write-Host ("  Применён preset '{0}'" -f $ProfileName) -ForegroundColor Gray
    Write-Host ("    Methods  : {0}" -f ($preset.Methods  -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    SplitPos : {0}" -f ($preset.SplitPos -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Foolings : {0}" -f ($preset.Foolings -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Autottls : {0}" -f ($preset.Autottls -join ', ')) -ForegroundColor DarkGray
    Write-Host ("    Note     : {0}" -f $preset.Note) -ForegroundColor DarkYellow
}

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
    }
}