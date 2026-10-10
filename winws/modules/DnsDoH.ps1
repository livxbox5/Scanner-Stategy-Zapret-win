# ===============================================================
# === DNS-over-HTTPS (DnsDoH.ps1) ===
# ===============================================================
#  Пул DoH-серверов для проверки (HTTPS, JSON API).
#  Меню: пункт 19.
#
#  Поиск:
#    # === RESOLVE-VIADOH ===       резолв через DoH
#    # === SHOW-DOHSERVERS ===      показать список
#    # === ADD-DOHSERVER ===        добавить
#    # === REMOVE-DOHSERVER ===     удалить
#    # === SET-DOHTESTDOMAIN ===    тестовый домен
#    # === TEST-DOHSERVERS ===      проверить все
#    # === SHOW-DOHMENU ===         меню пункта 19
# ===============================================================

# === RESOLVE-VIADOH ===
function Resolve-ViaDoH {
    param([string]$Domain, [string]$DohUrl)
    $result = [pscustomobject]@{ Ok = $false; IPs = @(); Err = ""; Status = "" }
    if (-not $DohUrl) { $result.Err = "empty URL"; return $result }
    $sep = if ($DohUrl -match '\?') { '&' } else { '?' }
    $url = "$DohUrl${sep}name=$Domain&type=A"
    try {
        $headers = @{ 'Accept' = 'application/dns-json' }
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 6 -ErrorAction Stop
        $status = if ($resp.Status) { $resp.Status } else { 0 }
        $result.Status = "Status=$status"
        $ips = @()
        if ($resp.Answer) {
            foreach ($ans in $resp.Answer) {
                if ($ans.type -eq 1 -and $ans.data) { $ips += $ans.data }
            }
        }
        if ($ips.Count -gt 0) { $result.Ok = $true; $result.IPs = $ips }
        elseif ($status -ne 0) { $result.Err = "DNS RCODE=$status" }
        else { $result.Err = "no A record" }
    } catch { $result.Err = $_.Exception.Message }
    return $result
}

# === SHOW-DOHSERVERS ===
function Show-DohServers {
    if ($Global:ZapretState.DohServers.Count -eq 0) { Write-Log "DoH-серверы не заданы" "WARN"; return }
    Write-Host ""
    Write-Host ("  DoH-серверы ({0} шт.), тестовый домен: {1}" -f $Global:ZapretState.DohServers.Count, $Global:ZapretState.DohTestDomain) -ForegroundColor Magenta
    Write-Host ""
    for ($j = 0; $j -lt $Global:ZapretState.DohServers.Count; $j++) {
        $key = if ($j -lt $Global:ZapretState.DohServerKeys.Count) { $Global:ZapretState.DohServerKeys[$j] } else { "" }
        Write-Host ("    [{0,2}]  {1,-42}  {2}" -f ($j + 1), $Global:ZapretState.DohServers[$j], $key)
    }
}

# === ADD-DOHSERVER ===
function Add-DohServer {
    $url = (Read-Host "URL DoH-сервера").Trim()
    if (-not $url) { return }
    if ($url -notmatch '^https://') { Write-Log "URL должен начинаться с https://" "ERR"; return }
    if ($Global:ZapretState.DohServers -contains $url) { Write-Log "Уже есть" "WARN"; return }
    $name = (Read-Host "Имя ключа (Enter — авто)").Trim()
    if (-not $name) { $name = "Doh_Server$($Global:ZapretState.DohServers.Count + 1)" }
    if ($name -notmatch '^Doh_') { $name = "Doh_$name" }
    $Global:ZapretState.DohServers    += $url
    $Global:ZapretState.DohServerKeys += $name
    Save-Settings
    Write-Log "Добавлен DoH: $url  ($name)"
}

# === REMOVE-DOHSERVER ===
function Remove-DohServer {
    if ($Global:ZapretState.DohServers.Count -eq 0) { Write-Log "Список пуст" "WARN"; return }
    Show-DohServers
    $n = 0
    $sel = Read-Host "Номер для удаления (Enter — отмена)"
    if ([string]::IsNullOrWhiteSpace($sel)) { return }
    if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $Global:ZapretState.DohServers.Count) { Write-Log "Неверный номер" "ERR"; return }
    $idx = $n - 1
    $removed = $Global:ZapretState.DohServers[$idx]
    $newSrv = @(); $newKeys = @()
    for ($j = 0; $j -lt $Global:ZapretState.DohServers.Count; $j++) {
        if ($j -eq $idx) { continue }
        $newSrv  += $Global:ZapretState.DohServers[$j]
        $newKeys += if ($j -lt $Global:ZapretState.DohServerKeys.Count) { $Global:ZapretState.DohServerKeys[$j] } else { "" }
    }
    $Global:ZapretState.DohServers    = $newSrv
    $Global:ZapretState.DohServerKeys = $newKeys
    Save-Settings
    Write-Log "Удалён DoH: $removed"
}

# === SET-DOHTESTDOMAIN ===
function Set-DohTestDomain {
    $d = (Read-Host "Тестовый домен").Trim()
    if (-not $d) { return }
    $Global:ZapretState.DohTestDomain = $d
    Save-Settings
}

# === TEST-DOHSERVERS ===
function Test-DohServers {
    $domain = $Global:ZapretState.DohTestDomain
    if (-not $domain) { $domain = (Read-Host "Домен").Trim(); if (-not $domain) { return }; $Global:ZapretState.DohTestDomain = $domain; Save-Settings }
    if ($Global:ZapretState.DohServers.Count -eq 0) { Write-Log "Нет DoH-серверов" "WARN"; return }

    Write-Host ""
    Write-Host ("  Проверка DoH: домен {0}, серверов {1}" -f $domain, $Global:ZapretState.DohServers.Count) -ForegroundColor Magenta
    Write-Host ""

    $sysSw = [System.Diagnostics.Stopwatch]::StartNew()
    $sysIps = @()
    try { $sysIps = @([System.Net.Dns]::GetHostAddresses($domain) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | ForEach-Object { $_.IPAddressToString }) } catch { }
    $sysSw.Stop()
    $sysOk = $sysIps.Count -gt 0
    $sysCol = if ($sysOk) { "Green" } else { "Red" }
    $sysText = if ($sysOk) { ($sysIps -join ', ') } else { "не отвечает" }
    if ($sysText.Length -gt 60) { $sysText = $sysText.Substring(0, 57) + "..." }
    Write-Host ("  [sys] system DNS                     {0,6} ms  {1}" -f $sysSw.ElapsedMilliseconds, $sysText) -ForegroundColor $sysCol
    Write-Host ""

    $ok = 0
    foreach ($server in $Global:ZapretState.DohServers) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Resolve-ViaDoH -Domain $domain -DohUrl $server
        $sw.Stop()
        $text = if ($r.Ok) { ($r.IPs -join ', ') } else { $r.Err }
        if ($text.Length -gt 60) { $text = $text.Substring(0, 57) + "..." }
        $col = if ($r.Ok) { "Green"; $ok++ } else { "Red" }
        $mark = if ($r.Ok) { "+" } else { "-" }
        Write-Host ("  [{0}] {1,-42} {2,6} ms  {3}" -f $mark, $server, $sw.ElapsedMilliseconds, $text) -ForegroundColor $col
    }
    Write-Host ""
    $totalCol = if ($ok -eq $Global:ZapretState.DohServers.Count) { "Green" } elseif ($ok -eq 0) { "Red" } else { "Yellow" }
    Write-Host ("  Итог: {0}/{1} DoH отвечают" -f $ok, $Global:ZapretState.DohServers.Count) -ForegroundColor $totalCol
}

# === SHOW-DOHMENU ===
function Show-DohMenu {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================" -ForegroundColor Magenta
        Write-Host "              DNS-over-HTTPS (DoH) — СЕРВЕРЫ                  " -ForegroundColor Magenta
        Write-Host "==============================================================" -ForegroundColor Magenta
        Write-Host ""
        Write-Host ("  Тестовый домен: {0}" -f $Global:ZapretState.DohTestDomain) -ForegroundColor Yellow
        Write-Host ""
        if ($Global:ZapretState.DohServers.Count -gt 0) {
            for ($j = 0; $j -lt $Global:ZapretState.DohServers.Count; $j++) {
                $key = if ($j -lt $Global:ZapretState.DohServerKeys.Count) { $Global:ZapretState.DohServerKeys[$j] } else { "" }
                Write-Host ("    [{0,2}]  {1}" -f ($j + 1), $Global:ZapretState.DohServers[$j])
                Write-Host ("           {0}" -f $key) -ForegroundColor DarkGray
            }
        } else { Write-Host "    <пусто>" -ForegroundColor DarkGray }
        Write-Host ""
        Write-Host "   1. Проверить все DoH-серверы" -ForegroundColor Green
        Write-Host "   2. Добавить DoH-сервер"
        Write-Host "   3. Удалить DoH-сервер"
        Write-Host "   4. Изменить тестовый домен"
        Write-Host "   5. Добавить стандартный набор"
        Write-Host ""
        Write-Host "   0. Назад" -ForegroundColor DarkGray
        Write-Host ""
        $c = Read-Host "Номер"
        switch ($c) {
            "1" { Test-DohServers;      Write-Host ""; Read-Host "Enter..." }
            "2" { Add-DohServer;         Write-Host ""; Read-Host "Enter..." }
            "3" { Remove-DohServer;      Write-Host ""; Read-Host "Enter..." }
            "4" { Set-DohTestDomain;     Write-Host ""; Read-Host "Enter..." }
            "5" {
                $defaults = @(
                    @{K="Doh_Google";     U="https://dns.google/dns-query"},
                    @{K="Doh_Cloudflare"; U="https://cloudflare-dns.com/dns-query"},
                    @{K="Doh_AdGuard";    U="https://dns.adguard-dns.com/dns-query"},
                    @{K="Doh_Quad9";      U="https://dns.quad9.net/dns-query"},
                    @{K="Doh_OpenDNS";    U="https://doh.opendns.com/dns-query"},
                    @{K="Doh_Yandex";     U="https://dns.yandex.ru/dns-query"}
                )
                $added = 0
                foreach ($d in $defaults) {
                    if ($Global:ZapretState.DohServers -notcontains $d.U) {
                        $Global:ZapretState.DohServers    += $d.U
                        $Global:ZapretState.DohServerKeys += $d.K
                        $added++
                    }
                }
                Save-Settings
                Write-Log "Добавлено стандартных DoH: $added"
                Write-Host ""; Read-Host "Enter..."
            }
            "0" { return }
        }
    }
}