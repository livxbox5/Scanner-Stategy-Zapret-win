# ===============================================================
# === DNS UDP (Dns.ps1) ===
# ===============================================================
#  Пул DNS-серверов для проверки (UDP, порт 53).
#  Меню: пункт 18.
#
#  Поиск:
#    # === RESOLVE-VIADNS ===       резолв домена через DNS
#    # === SHOW-DNSSERVERS ===      показать список
#    # === ADD-DNSSERVER ===        добавить
#    # === REMOVE-DNSSERVER ===     удалить
#    # === SET-DNSTESTDOMAIN ===    тестовый домен
#    # === TEST-DNSSERVERS ===      проверить все
#    # === SHOW-DNSMENU ===         меню пункта 18
# ===============================================================

# === RESOLVE-VIADNS ===
function Resolve-ViaDns {
    param([string]$Domain, [string]$Server)
    $result = [pscustomobject]@{ Ok = $false; IPs = @(); Err = "" }

    if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
        try {
            $r = Resolve-DnsName -Name $Domain -Type A -Server $Server -ErrorAction Stop
            $ips = @($r | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress)
            if ($ips.Count -gt 0) { $result.Ok = $true; $result.IPs = $ips }
            else { $result.Err = "no A record" }
        } catch { $result.Err = $_.Exception.Message }
    } else {
        try {
            $out = & nslookup $Domain $Server 2>&1
            $ips = @()
            foreach ($line in $out) {
                if ($line -match '^Address(es)?:\s+(.+)$') {
                    $candidate = $Matches[2].Trim()
                    if ($candidate -match '^\d{1,3}(\.\d{1,3}){3}$' -and $candidate -ne $Server) { $ips += $candidate }
                }
            }
            if ($ips.Count -gt 0) { $result.Ok = $true; $result.IPs = $ips }
            else { $result.Err = "no answer" }
        } catch { $result.Err = $_.Exception.Message }
    }
    return $result
}

# === SHOW-DNSSERVERS ===
function Show-DnsServers {
    if ($Global:ZapretState.DnsServers.Count -eq 0) { Write-Log "DNS-серверы не заданы" "WARN"; return }
    Write-Host ""
    Write-Host ("  DNS-серверы ({0} шт.), тестовый домен: {1}" -f $Global:ZapretState.DnsServers.Count, $Global:ZapretState.DnsTestDomain) -ForegroundColor Cyan
    Write-Host ""
    for ($j = 0; $j -lt $Global:ZapretState.DnsServers.Count; $j++) {
        $key = if ($j -lt $Global:ZapretState.DnsServerKeys.Count) { $Global:ZapretState.DnsServerKeys[$j] } else { "" }
        Write-Host ("    [{0,2}]  {1,-18}  {2}" -f ($j + 1), $Global:ZapretState.DnsServers[$j], $key)
    }
}

# === ADD-DNSSERVER ===
function Add-DnsServer {
    $ip = (Read-Host "IP DNS-сервера").Trim()
    if (-not $ip) { return }
    if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { Write-Log "Неверный IP" "ERR"; return }
    if ($Global:ZapretState.DnsServers -contains $ip) { Write-Log "Уже есть" "WARN"; return }
    $name = (Read-Host "Имя ключа (Enter — авто)").Trim()
    if (-not $name) { $name = "Dns_Server$($Global:ZapretState.DnsServers.Count + 1)" }
    if ($name -notmatch '^Dns_') { $name = "Dns_$name" }
    $Global:ZapretState.DnsServers    += $ip
    $Global:ZapretState.DnsServerKeys += $name
    Save-Settings
    Write-Log "Добавлен DNS: $ip  ($name)"
}

# === REMOVE-DNSSERVER ===
function Remove-DnsServer {
    if ($Global:ZapretState.DnsServers.Count -eq 0) { Write-Log "Список пуст" "WARN"; return }
    Show-DnsServers
    $n = 0
    $sel = Read-Host "Номер для удаления (Enter — отмена)"
    if ([string]::IsNullOrWhiteSpace($sel)) { return }
    if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 1 -or $n -gt $Global:ZapretState.DnsServers.Count) { Write-Log "Неверный номер" "ERR"; return }
    $idx = $n - 1
    $removed = $Global:ZapretState.DnsServers[$idx]
    $newSrv = @(); $newKeys = @()
    for ($j = 0; $j -lt $Global:ZapretState.DnsServers.Count; $j++) {
        if ($j -eq $idx) { continue }
        $newSrv  += $Global:ZapretState.DnsServers[$j]
        $newKeys += if ($j -lt $Global:ZapretState.DnsServerKeys.Count) { $Global:ZapretState.DnsServerKeys[$j] } else { "" }
    }
    $Global:ZapretState.DnsServers    = $newSrv
    $Global:ZapretState.DnsServerKeys = $newKeys
    Save-Settings
    Write-Log "Удалён DNS: $removed"
}

# === SET-DNSTESTDOMAIN ===
function Set-DnsTestDomain {
    $d = (Read-Host "Тестовый домен").Trim()
    if (-not $d) { return }
    $Global:ZapretState.DnsTestDomain = $d
    Save-Settings
}

# === TEST-DNSSERVERS ===
function Test-DnsServers {
    $domain = $Global:ZapretState.DnsTestDomain
    if (-not $domain) { $domain = (Read-Host "Домен").Trim(); if (-not $domain) { return }; $Global:ZapretState.DnsTestDomain = $domain; Save-Settings }
    if ($Global:ZapretState.DnsServers.Count -eq 0) { Write-Log "Нет DNS-серверов" "WARN"; return }

    Write-Host ""
    Write-Host ("  Проверка DNS: домен {0}, серверов {1}" -f $domain, $Global:ZapretState.DnsServers.Count) -ForegroundColor Cyan
    Write-Host ""

    $sysSw = [System.Diagnostics.Stopwatch]::StartNew()
    $sysIps = @()
    try { $sysIps = @([System.Net.Dns]::GetHostAddresses($domain) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | ForEach-Object { $_.IPAddressToString }) } catch { }
    $sysSw.Stop()
    $sysOk = $sysIps.Count -gt 0
    $sysCol = if ($sysOk) { "Green" } else { "Red" }
    $sysText = if ($sysOk) { ($sysIps -join ', ') } else { "не отвечает" }
    if ($sysText.Length -gt 60) { $sysText = $sysText.Substring(0, 57) + "..." }
    Write-Host ("  [sys] system             {0,6} ms  {1}" -f $sysSw.ElapsedMilliseconds, $sysText) -ForegroundColor $sysCol
    Write-Host ""

    $ok = 0
    foreach ($server in $Global:ZapretState.DnsServers) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Resolve-ViaDns -Domain $domain -Server $server
        $sw.Stop()
        $text = if ($r.Ok) { ($r.IPs -join ', ') } else { "не отвечает" }
        if ($text.Length -gt 60) { $text = $text.Substring(0, 57) + "..." }
        $col = if ($r.Ok) { "Green"; $ok++ } else { "Red" }
        $mark = if ($r.Ok) { "+" } else { "-" }
        Write-Host ("  [{0}] {1,-18} {2,6} ms  {3}" -f $mark, $server, $sw.ElapsedMilliseconds, $text) -ForegroundColor $col
    }
    Write-Host ""
    $totalCol = if ($ok -eq $Global:ZapretState.DnsServers.Count) { "Green" } elseif ($ok -eq 0) { "Red" } else { "Yellow" }
    Write-Host ("  Итог: {0}/{1} DNS отвечают" -f $ok, $Global:ZapretState.DnsServers.Count) -ForegroundColor $totalCol
}

# === SHOW-DNSMENU ===
function Show-DnsMenu {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host "                     DNS-СЕРВЕРЫ (UDP)                        " -ForegroundColor Cyan
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host ("  Тестовый домен: {0}" -f $Global:ZapretState.DnsTestDomain) -ForegroundColor Yellow
        Write-Host ""
        if ($Global:ZapretState.DnsServers.Count -gt 0) {
            for ($j = 0; $j -lt $Global:ZapretState.DnsServers.Count; $j++) {
                $key = if ($j -lt $Global:ZapretState.DnsServerKeys.Count) { $Global:ZapretState.DnsServerKeys[$j] } else { "" }
                Write-Host ("    [{0,2}]  {1,-18}  {2}" -f ($j + 1), $Global:ZapretState.DnsServers[$j], $key)
            }
        } else { Write-Host "    <пусто>" -ForegroundColor DarkGray }
        Write-Host ""
        Write-Host "   1. Проверить все DNS-серверы" -ForegroundColor Green
        Write-Host "   2. Добавить DNS-сервер"
        Write-Host "   3. Удалить DNS-сервер"
        Write-Host "   4. Изменить тестовый домен"
        Write-Host ""
        Write-Host "   0. Назад" -ForegroundColor DarkGray
        Write-Host ""
        $c = Read-Host "Номер"
        switch ($c) {
            "1" { Test-DnsServers;      Write-Host ""; Read-Host "Enter..." }
            "2" { Add-DnsServer;         Write-Host ""; Read-Host "Enter..." }
            "3" { Remove-DnsServer;      Write-Host ""; Read-Host "Enter..." }
            "4" { Set-DnsTestDomain;     Write-Host ""; Read-Host "Enter..." }
            "0" { return }
        }
    }
}