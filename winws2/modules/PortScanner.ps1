# ===============================================================
# === PORT SCANNER (PortScanner.ps1) — winws2 ===
# ===============================================================
#  Автоопределение сервиса по домену + подбор TCP/UDP портов.
#
#  Возможности:
#    - Known ports сервиса (hardcoded signatures)
#    - Live-порты запущенного процесса (Get-NetUDPEndpoint)
#    - Параллельный TCP-скан: quick / standard / full (1-65535)
#    - Параллельный UDP STUN-probe: known voice-порты / full (1-65535)
# ===============================================================

# ============================================================================
#  ПРЕСЕТЫ ПОРТОВ
# ============================================================================
$script:TopQuickPorts = @(
    21,22,23,25,53,80,110,111,135,139,143,161,389,443,445,465,587,636,
    993,995,1080,1433,1521,1723,2049,2082,2083,2086,2087,2095,2096,
    3000,3128,3306,3389,4443,5060,5061,5222,5223,5432,5900,5984,6379,
    7001,8080,8081,8443,8888,9000,9090,9200,9418,10000,11211,27017
)

$script:TopStandardPorts = @(
    $script:TopQuickPorts
    1,7,9,13,19,26,37,49,79,81,82,83,84,85,88,89,90,99,100,106,113,119,144,146,
    199,427,444,458,481,497,500,515,548,554,563,593,601,623,631,646,666,691,700,
    873,902,989,990,1025,1026,1027,1028,1029,1194,1241,1352,1434,1701,1812,1813,
    1900,2000,2222,2375,2376,3260,3268,3269,4444,4567,5000,5269,5357,5555,5632,
    5666,5672,5683,5800,6000,6666,6667,6668,6669,7070,8000,8008,8010,8088,8090,
    9100,9300,9999,27018,28017,32768,49152,49153,50000,50001,50002
)

# ============================================================================
#  СИГНАТУРЫ СЕРВИСОВ
# ============================================================================
$script:ServiceSignatures = [ordered]@{

    'Discord' = @{
        Patterns     = @('discord.com','discordapp.com','discord.gg','discord.media',
                         'discordapp.net','discordstatus.com')
        TcpPorts     = @(443, 2053, 2083, 2087, 2096, 8443)
        UdpPorts     = @(19294..19344) + @(50000..50100) + @(3478, 5349)
        ProcessNames = @('Discord','DiscordPTB','DiscordCanary','DiscordDevelopment')
        TcpHint      = '443 (web/gateway/cdn), 2053/2083/2087/2096/8443 (media TLS)'
        UdpHint      = '19294-19344 + 50000-50100 (voice/RTP), 3478/5349 (STUN)'
    }

    'WhatsApp' = @{
        Patterns     = @('whatsapp.com','whatsapp.net','wa.me','mmg.whatsapp.net')
        TcpPorts     = @(80, 443, 5222, 5223, 5228, 4244)
        UdpPorts     = @(3478, 45395, 50318, 59234)
        ProcessNames = @('WhatsApp','WhatsAppDesktop')
        TcpHint      = '443 (web), 5222/5223 (XMPP), 5228/4244 (push)'
        UdpHint      = '3478 (STUN), 45395/50318/59234 (voice)'
    }

    'YouTube' = @{
        Patterns     = @('youtube.com','youtu.be','ytimg.com','googlevideo.com',
                         'youtube-nocookie.com','yt3.ggpht.com')
        TcpPorts     = @(80, 443)
        UdpPorts     = @(443) + @(19302..19309)
        ProcessNames = @()
        TcpHint      = '443 (web/API), 80 (HTTP)'
        UdpHint      = '443 (QUIC), 19302-19309 (WebRTC)'
    }

    'Google' = @{
        Patterns     = @('google.com','gstatic.com','googleapis.com','googleusercontent.com',
                         'googlesyndication.com','gvt1.com','gvt2.com')
        TcpPorts     = @(80, 443)
        UdpPorts     = @(443, 3478, 5349)
        ProcessNames = @()
        TcpHint      = '443 (web/API), 80 (HTTP)'
        UdpHint      = '443 (QUIC), 3478/5349 (STUN)'
    }

    'Telegram' = @{
        Patterns     = @('telegram.org','t.me','telesco.pe','telegram.me','telegram.dog')
        TcpPorts     = @(80, 443, 5222, 5223)
        UdpPorts     = @(443, 3478, 5349)
        ProcessNames = @('Telegram','TelegramDesktop')
        TcpHint      = '443 (MTProto/Web), 5222/5223 (MTProto TCP)'
        UdpHint      = '443 (QUIC), 3478/5349 (STUN)'
    }

    'Signal' = @{
        Patterns     = @('signal.org','whispersystems.org','signal.art')
        TcpPorts     = @(80, 443)
        UdpPorts     = @(443, 3478)
        ProcessNames = @('Signal','SignalDesktop')
        TcpHint      = '443 (web/relay), 80 (HTTP)'
        UdpHint      = '443 (QUIC), 3478 (STUN)'
    }

    'Steam' = @{
        Patterns     = @('steamcommunity.com','steampowered.com','steamstatic.com',
                         'steamusercontent.com','steamcontent.com','steamgames.com')
        TcpPorts     = @(80, 443) + @(27015..27030) + @(27036, 27037)
        UdpPorts     = @(27000..27031) + @(27036, 3478, 4379, 4380)
        ProcessNames = @('steam','steamwebhelper','steamservice')
        TcpHint      = '443 (web/API), 27015-27030 (client), 27036-27037 (Remote Play)'
        UdpHint      = '27000-27031 (servers), 27036 (Remote Play), 3478 (STUN)'
    }

    'Zoom' = @{
        Patterns     = @('zoom.us','zoom.com','zoomgov.com','zoomcdn.com')
        TcpPorts     = @(80, 443) + @(8801..8810)
        UdpPorts     = @(8801..8810) + @(3478, 3479, 3480, 3481)
        ProcessNames = @('Zoom','CptHost')
        TcpHint      = '443 (web), 8801-8810 (media)'
        UdpHint      = '8801-8810 (media), 3478-3481 (STUN)'
    }

    'Skype' = @{
        Patterns     = @('skype.com','skype.net','skypedata.akadns.net')
        TcpPorts     = @(80, 443) + @(3478..3481)
        UdpPorts     = @(3478..3481)
        ProcessNames = @('Skype','SkypeApp','SkypeBackgroundHost')
        TcpHint      = '443 (web), 3478-3481 (P2P/VoIP)'
        UdpHint      = '3478-3481 (P2P/VoIP)'
    }

    'Slack' = @{
        Patterns     = @('slack.com','slack-edge.com','slack-msgs.com','slackb.com')
        TcpPorts     = @(80, 443)
        UdpPorts     = @(443, 3478, 5349)
        ProcessNames = @('slack')
        TcpHint      = '443 (web/API), 80 (HTTP)'
        UdpHint      = '443 (QUIC), 3478/5349 (Huddles)'
    }

    'Twitch' = @{
        Patterns     = @('twitch.tv','ttvnw.net','jtvnw.net','twitchcdn.net')
        TcpPorts     = @(80, 443, 1935)
        UdpPorts     = @(443)
        ProcessNames = @('Twitch')
        TcpHint      = '443 (web/stream), 1935 (RTMP)'
        UdpHint      = '443 (QUIC)'
    }

    'TikTok' = @{
        Patterns     = @('tiktok.com','tiktokcdn.com','tiktokv.com','byteoversea.com','ibytedtos.com')
        TcpPorts     = @(80, 443)
        UdpPorts     = @(443)
        ProcessNames = @()
        TcpHint      = '443 (web/API), 80 (HTTP)'
        UdpHint      = '443 (QUIC)'
    }

    'Netflix' = @{
        Patterns     = @('netflix.com','nflxvideo.net','nflximg.net','nflxext.com','nflxso.net')
        TcpPorts     = @(80, 443)
        UdpPorts     = @(443)
        ProcessNames = @()
        TcpHint      = '443 (web/stream), 80 (HTTP)'
        UdpHint      = '443 (QUIC)'
    }

    'Spotify' = @{
        Patterns     = @('spotify.com','scdn.co','spotifycdn.com','spotify.link')
        TcpPorts     = @(80, 443, 4070)
        UdpPorts     = @(443, 4070)
        ProcessNames = @('Spotify','SpotifyWebHelper')
        TcpHint      = '443 (web/API), 4070 (stream)'
        UdpHint      = '443 (QUIC), 4070 (stream)'
    }

    'Cloudflare' = @{
        Patterns     = @('cloudflare.com','cdnjs.com','cloudflare-dns.com')
        TcpPorts     = @(80, 443, 8080, 8443, 2052, 2053, 2082, 2083, 2086, 2087, 2095, 2096)
        UdpPorts     = @(443, 7844)
        ProcessNames = @()
        TcpHint      = '443/80, 8080/8443, 2052-2096 (CDN edge)'
        UdpHint      = '443 (QUIC), 7844 (WARP)'
    }

    'Default' = @{
        Patterns     = @()
        TcpPorts     = @(80, 443, 8080, 8443)
        UdpPorts     = @(443, 3478, 5349)
        ProcessNames = @()
        TcpHint      = 'стандартные веб-порты'
        UdpHint      = 'стандартные UDP-порты'
    }
}

# ============================================================================
#  ОПРЕДЕЛЕНИЕ СЕРВИСА
# ============================================================================
function Get-ServiceByDomain {
    param([string]$Domain)
    if (-not $Domain) { return 'Default' }
    $d = $Domain.ToLowerInvariant()
    foreach ($name in $script:ServiceSignatures.Keys) {
        if ($name -eq 'Default') { continue }
        foreach ($pat in $script:ServiceSignatures[$name].Patterns) {
            if ($d.Contains($pat)) { return $name }
        }
    }
    return 'Default'
}

function Get-ServiceSignature {
    param([string]$Service)
    if ($script:ServiceSignatures.Contains($Service)) {
        return $script:ServiceSignatures[$Service]
    }
    return $script:ServiceSignatures['Default']
}

# ============================================================================
#  RESOLVE / TCP / LIVE
# ============================================================================
function Resolve-DomainIps {
    param([string]$Domain)
    try {
        return @([System.Net.Dns]::GetHostAddresses($Domain) |
                 Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                 ForEach-Object { $_.IPAddressToString } | Sort-Object -Unique)
    } catch { return @() }
}

function Test-TcpPort {
    param(
        [string]$TargetHost,
        [int]$Port,
        [int]$TimeoutMs = 1500
    )
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $task = $client.ConnectAsync($TargetHost, $Port)
        if ($task.Wait($TimeoutMs) -and $client.Connected) { return $true }
        return $false
    } catch { return $false } finally {
        if ($client) { try { $client.Close() } catch {} }
    }
}

function Get-LiveProcessPorts {
    param([string[]]$ProcessNames)

    $r = [pscustomobject]@{
        Pids      = @()
        TcpLocal  = @()
        TcpRemote = @()
        UdpLocal  = @()
    }
    if (-not $ProcessNames -or $ProcessNames.Count -eq 0) { return $r }

    $tcpL = New-Object System.Collections.Generic.HashSet[int]
    $tcpR = New-Object System.Collections.Generic.HashSet[int]
    $udpL = New-Object System.Collections.Generic.HashSet[int]
    $pids = New-Object System.Collections.Generic.HashSet[int]

    foreach ($name in $ProcessNames) {
        foreach ($p in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            [void]$pids.Add([int]$p.Id)
            foreach ($c in @(Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue)) {
                if ($c.LocalPort)  { [void]$tcpL.Add([int]$c.LocalPort) }
                if ($c.RemotePort) { [void]$tcpR.Add([int]$c.RemotePort) }
            }
            foreach ($e in @(Get-NetUDPEndpoint -OwningProcess $p.Id -ErrorAction SilentlyContinue)) {
                if ($e.LocalPort) { [void]$udpL.Add([int]$e.LocalPort) }
            }
        }
    }

    $r.Pids      = @($pids | Sort-Object)
    $r.TcpLocal  = @($tcpL | Sort-Object)
    $r.TcpRemote = @($tcpR | Sort-Object)
    $r.UdpLocal  = @($udpL | Sort-Object)
    return $r
}

# ============================================================================
#  СВОРАЧИВАНИЕ ПОРТОВ В ДИАПАЗОНЫ
# ============================================================================
function ConvertTo-PortRanges {
    param([int[]]$Ports)
    if (-not $Ports -or $Ports.Count -eq 0) { return @() }
    $sorted = @($Ports | Sort-Object -Unique)
    $ranges = New-Object System.Collections.Generic.List[string]
    $start  = $sorted[0]; $prev = $sorted[0]
    for ($i = 1; $i -lt $sorted.Count; $i++) {
        $cur = $sorted[$i]
        if ($cur -eq $prev + 1) { $prev = $cur; continue }
        if ($start -eq $prev) { $ranges.Add("$start") } else { $ranges.Add("$start-$prev") }
        $start = $cur; $prev = $cur
    }
    if ($start -eq $prev) { $ranges.Add("$start") } else { $ranges.Add("$start-$prev") }
    return @($ranges)
}

# ============================================================================
#  ШИРОКИЙ TCP-СКАН (параллельный, runspace pool)
# ============================================================================
function Invoke-TcpWideScan {
    param(
        [string]$Target,
        [int[]]$Ports,
        [int]$Parallel   = 128,
        [int]$TimeoutMs  = 400,
        [switch]$Quiet
    )

    if (-not $Target -or -not $Ports -or $Ports.Count -eq 0) { return @() }
    if ($Parallel -lt 1)   { $Parallel = 1 }
    if ($Parallel -gt 512) { $Parallel = 512 }

    $open  = New-Object System.Collections.Generic.List[int]
    $total = $Ports.Count

    $chunkCount = [Math]::Min($Parallel, $total)
    $chunkSize  = [Math]::Ceiling($total / $chunkCount)
    $chunks = @()
    for ($i = 0; $i -lt $total; $i += $chunkSize) {
        $end = [Math]::Min($i + $chunkSize - 1, $total - 1)
        $chunks += ,@($Ports[$i..$end])
    }

    $pool = [runspacefactory]::CreateRunspacePool(1, $chunkCount)
    $pool.Open()

    $handles = @()
    foreach ($chunk in $chunks) {
        $ps = [powershell]::Create().AddScript({
            param($t, $ports, $ms)
            $found = @()
            foreach ($p in $ports) {
                $client = $null
                try {
                    $client = New-Object System.Net.Sockets.TcpClient
                    $task = $client.ConnectAsync($t, $p)
                    if ($task.Wait($ms) -and $client.Connected) { $found += $p }
                } catch {}
                finally { if ($client) { try { $client.Close() } catch {} } }
            }
            return ,$found
        }).AddArgument($Target).AddArgument($chunk).AddArgument($TimeoutMs)
        $ps.RunspacePool = $pool
        $handles += [pscustomobject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
    }

    $done = 0
    foreach ($h in $handles) {
        try {
            $result = $h.PS.EndInvoke($h.Handle)
            if ($result) { foreach ($p in $result) { [void]$open.Add([int]$p) } }
        } catch {}
        finally { $h.PS.Dispose() }
        $done++
        if (-not $Quiet) {
            Write-Progress -Activity "TCP scan $Target" `
                -Status ("{0}/{1} чанков, открыто: {2}" -f $done, $handles.Count, $open.Count) `
                -PercentComplete (($done / $handles.Count) * 100)
        }
    }

    $pool.Close()
    $pool.Dispose()
    if (-not $Quiet) { Write-Progress -Activity "TCP scan $Target" -Completed }

    return @($open | Sort-Object -Unique)
}

# ============================================================================
#  UDP STUN-PROBE (одиночный)
# ============================================================================
function Test-UdpStunProbe {
    param(
        [string]$Target,
        [int]$Port,
        [int]$TimeoutMs = 800
    )
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.UdpClient
        $client.Client.ReceiveTimeout = $TimeoutMs
        $client.Connect($Target, $Port)
        $req = [byte[]](
            0x00,0x01, 0x00,0x00,
            0x21,0x12,0xA4,0x42,
            0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C
        )
        [void]$client.Send($req, $req.Length)
        $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $data = $client.Receive([ref]$remote)
        if ($data -and $data.Length -ge 20) {
            $isStun = ($data[0] -eq 0x01) -and (($data[1] -eq 0x01) -or ($data[1] -eq 0x11))
            if ($isStun) { return [pscustomobject]@{ Port = $Port; Open = $true;  Type = 'STUN';     Bytes = $data.Length } }
            return [pscustomobject]@{ Port = $Port; Open = $true;  Type = 'Response'; Bytes = $data.Length }
        }
        return [pscustomobject]@{ Port = $Port; Open = $false; Type = 'Empty';    Bytes = 0 }
    }
    catch [System.Net.Sockets.SocketException] {
        $code = $_.Exception.SocketErrorCode
        switch ($code) {
            'ConnectionReset' { return [pscustomobject]@{ Port = $Port; Open = $false; Type = 'ICMP-closed'; Bytes = 0 } }
            'TimedOut'        { return [pscustomobject]@{ Port = $Port; Open = $false; Type = 'Timeout';     Bytes = 0 } }
            default           { return [pscustomobject]@{ Port = $Port; Open = $false; Type = "Err:$code";  Bytes = 0 } }
        }
    }
    catch { return [pscustomobject]@{ Port = $Port; Open = $false; Type = 'Error'; Bytes = 0 } }
    finally { if ($client) { try { $client.Dispose() } catch {} } }
}

# ============================================================================
#  ШИРОКИЙ UDP-СКАН (параллельный STUN-probe)
# ============================================================================
function Invoke-UdpWideScan {
    param(
        [string]$Target,
        [int[]]$Ports,
        [int]$Parallel  = 128,
        [int]$TimeoutMs = 600,
        [switch]$Quiet
    )

    if (-not $Target -or -not $Ports -or $Ports.Count -eq 0) { return @() }
    if ($Parallel -lt 1)   { $Parallel = 1 }
    if ($Parallel -gt 256) { $Parallel = 256 }

    $openPorts = New-Object System.Collections.Generic.List[object]
    $closedUdp = New-Object System.Collections.Generic.List[int]
    $total     = $Ports.Count

    $chunkCount = [Math]::Min($Parallel, $total)
    $chunkSize  = [Math]::Ceiling($total / $chunkCount)
    $chunks = @()
    for ($i = 0; $i -lt $total; $i += $chunkSize) {
        $end = [Math]::Min($i + $chunkSize - 1, $total - 1)
        $chunks += ,@($Ports[$i..$end])
    }

    $pool = [runspacefactory]::CreateRunspacePool(1, $chunkCount)
    $pool.Open()

    $handles = @()
    foreach ($chunk in $chunks) {
        $ps = [powershell]::Create().AddScript({
            param($t, $ports, $ms)

            function Local-Stun($target, $port, $timeout) {
                $c = $null
                try {
                    $c = New-Object System.Net.Sockets.UdpClient
                    $c.Client.ReceiveTimeout = $timeout
                    $c.Connect($target, $port)
                    $req = [byte[]](0x00,0x01,0x00,0x00,0x21,0x12,0xA4,0x42,
                                    0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C)
                    [void]$c.Send($req, $req.Length)
                    $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                    $data = $c.Receive([ref]$remote)
                    if ($data -and $data.Length -ge 20) {
                        $isStun = ($data[0] -eq 0x01) -and (($data[1] -eq 0x01) -or ($data[1] -eq 0x11))
                        if ($isStun) { return @{ Open=$true; Type='STUN'; Bytes=$data.Length } }
                        return @{ Open=$true; Type='Response'; Bytes=$data.Length }
                    }
                    return @{ Open=$false; Type='Empty'; Bytes=0 }
                }
                catch [System.Net.Sockets.SocketException] {
                    $code = $_.Exception.SocketErrorCode
                    if ($code -eq 'ConnectionReset') { return @{ Open=$false; Type='ICMP-closed'; Bytes=0 } }
                    if ($code -eq 'TimedOut')        { return @{ Open=$false; Type='Timeout';     Bytes=0 } }
                    return @{ Open=$false; Type="Err:$code"; Bytes=0 }
                }
                catch { return @{ Open=$false; Type='Error'; Bytes=0 } }
                finally { if ($c) { try { $c.Dispose() } catch {} } }
            }

            $res = @()
            foreach ($p in $ports) {
                $r = Local-Stun $t $p $ms
                $res += [pscustomobject]@{ Port=$p; Open=$r.Open; Type=$r.Type; Bytes=$r.Bytes }
            }
            return ,$res
        }).AddArgument($Target).AddArgument($chunk).AddArgument($TimeoutMs)
        $ps.RunspacePool = $pool
        $handles += [pscustomobject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
    }

    $done = 0
    foreach ($h in $handles) {
        try {
            $result = $h.PS.EndInvoke($h.Handle)
            if ($result) {
                foreach ($r in $result) {
                    if ($r.Open)                       { [void]$openPorts.Add($r) }
                    elseif ($r.Type -eq 'ICMP-closed') { [void]$closedUdp.Add([int]$r.Port) }
                }
            }
        } catch {}
        finally { $h.PS.Dispose() }
        $done++
        if (-not $Quiet) {
            Write-Progress -Activity "UDP scan $Target" `
                -Status ("{0}/{1} чанков | open: {2} | ICMP-closed: {3}" -f $done, $handles.Count, $openPorts.Count, $closedUdp.Count) `
                -PercentComplete (($done / $handles.Count) * 100)
        }
    }

    $pool.Close()
    $pool.Dispose()
    if (-not $Quiet) { Write-Progress -Activity "UDP scan $Target" -Completed }

    return [pscustomobject]@{
        Open       = @($openPorts | Sort-Object Port)
        IcmpClosed = @($closedUdp | Sort-Object -Unique)
    }
}

# ============================================================================
#  ЛОКАТОР ПАПКИ lists/
# ============================================================================
function Get-ListsDir {
    $candidates = New-Object System.Collections.Generic.List[string]

    $p = [string]$Global:ZapretState.TxtPath
    if ($p) {
        if (Test-Path $p) {
            $item = Get-Item $p
            if ($item.PSIsContainer) { $candidates.Add($item.FullName) | Out-Null }
            else                     { $candidates.Add($item.DirectoryName) | Out-Null }
        } else {
            $parent = Split-Path $p -Parent
            if ($parent -and (Test-Path $parent)) { $candidates.Add($parent) | Out-Null }
        }
    }

    $modDir = $PSScriptRoot
    if ($modDir) {
        $candidates.Add((Join-Path (Split-Path $modDir -Parent) 'lists')) | Out-Null
        $candidates.Add((Join-Path $modDir 'lists'))                      | Out-Null
        $candidates.Add((Join-Path (Split-Path (Split-Path $modDir -Parent) -Parent) 'lists')) | Out-Null
        $candidates.Add((Join-Path (Split-Path $modDir -Parent) '..\lists')) | Out-Null
    }

    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) {
            $full = (Get-Item $c).FullName
            if ((Get-Item $full).PSIsContainer) { return $full }
        }
    }
    return $null
}

# ============================================================================
#  ЧТЕНИЕ ДОМЕНОВ ИЗ .txt
# ============================================================================
function Read-DomainsFromFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in (Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)) {
        $l = $line.Trim()
        if (-not $l -or $l.StartsWith('#')) { continue }
        $l = $l -replace '^https?://',''
        $l = ($l -split '/')[0]
        $l = ($l -split ':')[0]
        $l = $l.TrimStart('.').ToLowerInvariant()
        if ($l -match '^[a-z0-9]([a-z0-9\-\.]*[a-z0-9])?\.[a-z]{2,}$') {
            if (-not $out.Contains($l)) { $out.Add($l) | Out-Null }
        }
    }
    return @($out.ToArray())
}

# ============================================================================
#  ГЛАВНАЯ ФУНКЦИЯ СКАНА (по домену)
# ============================================================================
function Invoke-DomainPortScan {
    param(
        [string[]]$Domains,
        [switch]$SkipTcpScan,
        [ValidateRange(200, 30000)]
        [int]$TimeoutMs = 1500,
        [switch]$Quiet,

        [ValidateSet('none','quick','standard','full','custom')]
        [string]$WideTcp = 'none',

        [switch]$UdpProbe,
        [switch]$UdpFull
    )

    if (-not $Domains -or $Domains.Count -eq 0) {
        Write-Log "PortScanner: список доменов пуст" "WARN"
        return @()
    }

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($raw in $Domains) {
        $d = $raw.Trim()
        if (-not $d) { continue }
        $d = $d -replace '^https?://',''
        $d = ($d -split '/')[0]
        $d = ($d -split ':')[0]
        $d = $d.TrimStart('.').ToLowerInvariant()
        if (-not $d) { continue }

        if (-not $Quiet) {
            Write-Host ""
            Write-Host ("  ── {0}" -f $d) -ForegroundColor Cyan
        }

        $service = Get-ServiceByDomain -Domain $d
        $sig     = Get-ServiceSignature -Service $service

        if (-not $Quiet) {
            Write-Host ("     service : {0}" -f $service) -ForegroundColor Yellow
        }

        $ips = @(Resolve-DomainIps -Domain $d)
        if (-not $Quiet) {
            if ($ips.Count) { Write-Host ("     IP      : {0}" -f ($ips -join ', ')) -ForegroundColor Gray }
            else            { Write-Host  "     IP      : <не разрешён>" -ForegroundColor DarkRed }
        }

        if ($ips.Count -eq 0) {
            $results.Add([pscustomobject]@{
                Domain = $d; Service = $service; IPs = @()
                TcpPorts = @($sig.TcpPorts); UdpPorts = @($sig.UdpPorts)
                TcpOpen = @(); WideOpen = @(); UdpProbed = @()
                LivePids = @(); LiveUdp = @(); LiveTcpRemote = @()
                TcpRanges = @(); UdpRanges = @()
                TcpHint = $sig.TcpHint; UdpHint = $sig.UdpHint
            }) | Out-Null
            continue
        }

        $targetAddr = $ips[0]

        # ─── TCP known ───
        $tcpOpen = @()
        if (-not $SkipTcpScan) {
            if (-not $Quiet) {
                Write-Host ("     TCP known ({0} портов, timeout {1}ms)..." -f $sig.TcpPorts.Count, $TimeoutMs) -ForegroundColor DarkGray
            }
            foreach ($p in $sig.TcpPorts) {
                if (Test-TcpPort -TargetHost $targetAddr -Port $p -TimeoutMs $TimeoutMs) {
                    $tcpOpen += $p
                }
            }
            if (-not $Quiet) {
                if ($tcpOpen.Count) { Write-Host ("     TCP known open: {0}" -f ($tcpOpen -join ', ')) -ForegroundColor Green }
                else                { Write-Host  "     TCP known open: <нет ответа>" -ForegroundColor DarkGray }
            }
        }

        # ─── TCP wide ───
        $wideOpen = @()
        if ($WideTcp -ne 'none') {
            $portsToScan = switch ($WideTcp) {
                'quick'    { $script:TopQuickPorts }
                'standard' { $script:TopStandardPorts }
                'full'     { 1..65535 }
                'custom'   { @() }
            }

            if ($WideTcp -eq 'full') {
                if (-not $Quiet) {
                    Write-Host ("     TCP wide FULL 1-65535 — это может занять 3-5 минут...") -ForegroundColor Yellow
                }
                $wideOpen = @(Invoke-TcpWideScan -Target $targetAddr -Ports $portsToScan -Parallel 256 -TimeoutMs 250 -Quiet:$Quiet)
            } else {
                if (-not $Quiet) {
                    Write-Host ("     TCP wide {0} ({1} портов)..." -f $WideTcp.ToUpper(), $portsToScan.Count) -ForegroundColor DarkGray
                }
                $wideOpen = @(Invoke-TcpWideScan -Target $targetAddr -Ports $portsToScan -Parallel 128 -TimeoutMs 400 -Quiet:$Quiet)
            }

            if (-not $Quiet) {
                if ($wideOpen.Count) { Write-Host ("     TCP wide open: {0}" -f ($wideOpen -join ', ')) -ForegroundColor Green }
                else                 { Write-Host  "     TCP wide open: <нет>" -ForegroundColor DarkGray }
            }
        }

        # ─── UDP STUN probe / UDP FULL ───
        $udpProbed = @()
        if ($UdpProbe -or $UdpFull) {
            if ($UdpFull) {
                if (-not $Quiet) {
                    Write-Host ("     UDP FULL 1-65535 — это займёт 10-20 минут...") -ForegroundColor Yellow
                }
                $udpRes = Invoke-UdpWideScan -Target $targetAddr -Ports (1..65535) -Parallel 256 -TimeoutMs 500 -Quiet:$Quiet
            } else {
                if (-not $Quiet) {
                    Write-Host ("     UDP STUN probe ({0} портов)..." -f $sig.UdpPorts.Count) -ForegroundColor DarkGray
                }
                $udpRes = Invoke-UdpWideScan -Target $targetAddr -Ports $sig.UdpPorts -Parallel 64 -TimeoutMs 800 -Quiet:$Quiet
            }
            $udpProbed = @($udpRes.Open)
            if (-not $Quiet) {
                if ($udpProbed.Count) {
                    Write-Host ("     UDP open: {0}" -f (($udpProbed | ForEach-Object { $_.Port }) -join ', ')) -ForegroundColor Green
                } else {
                    Write-Host  "     UDP open: <нет ответа>" -ForegroundColor DarkGray
                }
            }
        }

        # ─── Live-порты процессов ───
        $live = [pscustomobject]@{ Pids=@(); TcpLocal=@(); TcpRemote=@(); UdpLocal=@() }
        if ($sig.ProcessNames.Count -gt 0) {
            if (-not $Quiet) {
                Write-Host ("     Live scan ({0})..." -f ($sig.ProcessNames -join ', ')) -ForegroundColor DarkGray
            }
            $live = Get-LiveProcessPorts -ProcessNames $sig.ProcessNames
            if (-not $Quiet) {
                if ($live.Pids.Count) {
                    Write-Host ("     Live PIDs : {0}" -f ($live.Pids -join ', ')) -ForegroundColor DarkGray
                    if ($live.UdpLocal.Count)  { Write-Host ("     Live UDP  : {0}" -f ($live.UdpLocal -join ', ')) -ForegroundColor Green }
                    if ($live.TcpRemote.Count) { Write-Host ("     Live TCPr : {0}" -f ($live.TcpRemote -join ', ')) -ForegroundColor Green }
                } else {
                    Write-Host "     Live: процесс не запущен" -ForegroundColor DarkGray
                }
            }
        }

        # ─── Финальные списки ───
        $finalTcp = @()
        if ($tcpOpen.Count)        { $finalTcp += $tcpOpen }
        if ($wideOpen.Count)       { $finalTcp += $wideOpen }
        if ($live.TcpRemote.Count) { $finalTcp += $live.TcpRemote }
        $finalTcp += $sig.TcpPorts
        $finalTcp = @($finalTcp | Sort-Object -Unique)

        $finalUdp = @()
        if ($live.UdpLocal.Count) { $finalUdp += $live.UdpLocal }
        if ($udpProbed.Count)     { $finalUdp += ($udpProbed | ForEach-Object { $_.Port }) }
        $finalUdp += $sig.UdpPorts
        $finalUdp = @($finalUdp | Sort-Object -Unique)

        $results.Add([pscustomobject]@{
            Domain        = $d
            Service       = $service
            IPs           = $ips
            TcpPorts      = $finalTcp
            UdpPorts      = $finalUdp
            TcpOpen       = $tcpOpen
            WideOpen      = $wideOpen
            UdpProbed     = $udpProbed
            LivePids      = $live.Pids
            LiveUdp       = $live.UdpLocal
            LiveTcpRemote = $live.TcpRemote
            TcpRanges     = @(ConvertTo-PortRanges -Ports $finalTcp)
            UdpRanges     = @(ConvertTo-PortRanges -Ports $finalUdp)
            TcpHint       = $sig.TcpHint
            UdpHint       = $sig.UdpHint
        }) | Out-Null
    }

    return @($results.ToArray())
}

# ============================================================================
#  СВОДКА
# ============================================================================
function Show-PortScanSummary {
    param([array]$Results)

    if (-not $Results -or $Results.Count -eq 0) { return }

    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Magenta
    Write-Host "  PORT SCAN SUMMARY" -ForegroundColor Magenta
    Write-Host ("=" * 78) -ForegroundColor Magenta

    Write-Host ("  {0,-38} {1,-10} {2,-22}" -f 'Domain', 'Service', 'TCP open (known)') -ForegroundColor DarkGray
    Write-Host ("  " + ("-" * 72)) -ForegroundColor DarkGray
    foreach ($r in $Results) {
        $d = $r.Domain; if ($d.Length -gt 38) { $d = $d.Substring(0, 35) + '...' }
        $t = if ($r.TcpOpen.Count) { $r.TcpOpen -join ',' } else { '-' }
        Write-Host ("  {0,-38} {1,-10} {2,-22}" -f $d, $r.Service, $t) -ForegroundColor White
    }

    $anyWide = @($Results | Where-Object { $_.WideOpen -and $_.WideOpen.Count -gt 0 })
    if ($anyWide.Count -gt 0) {
        Write-Host ""
        Write-Host "  --- Wide TCP (сверх известных) ---" -ForegroundColor DarkCyan
        foreach ($r in $anyWide) {
            $extra = @($r.WideOpen | Where-Object { $r.TcpOpen -notcontains $_ })
            if ($extra.Count -gt 0) {
                Write-Host ("  {0,-38} {1}" -f $r.Domain, ($extra -join ',')) -ForegroundColor Green
            }
        }
    }

    $anyUdp = @($Results | Where-Object { $_.UdpProbed -and $_.UdpProbed.Count -gt 0 })
    if ($anyUdp.Count -gt 0) {
        Write-Host ""
        Write-Host "  --- UDP STUN probe (ответили) ---" -ForegroundColor DarkCyan
        foreach ($r in $anyUdp) {
            $str = @($r.UdpProbed | ForEach-Object { "$($_.Port) [$($_.Type)]" }) -join ', '
            Write-Host ("  {0,-38} {1}" -f $r.Domain, $str) -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "  --- По сервисам ---" -ForegroundColor DarkCyan
    foreach ($grp in ($Results | Group-Object Service)) {
        $tcpAll  = @(ConvertTo-PortRanges -Ports @($grp.Group | ForEach-Object { $_.TcpPorts }))
        $udpAll  = @(ConvertTo-PortRanges -Ports @($grp.Group | ForEach-Object { $_.UdpPorts }))
        $liveUdp = @($grp.Group | ForEach-Object { $_.LiveUdp } | Sort-Object -Unique)

        Write-Host ("  [{0}]  ({1} доменов)" -f $grp.Name, $grp.Count) -ForegroundColor Yellow
        Write-Host ("      TCP: {0}" -f ($tcpAll -join ',')) -ForegroundColor White
        Write-Host ("      UDP: {0}" -f ($udpAll -join ',')) -ForegroundColor White
        if ($liveUdp.Count) {
            Write-Host ("      UDP live: {0}" -f ($liveUdp -join ',')) -ForegroundColor Green
        }
        $hint = ($grp.Group | Select-Object -First 1)
        Write-Host ("      hint TCP: {0}" -f $hint.TcpHint) -ForegroundColor DarkGray
        Write-Host ("      hint UDP: {0}" -f $hint.UdpHint) -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  --- Для вставки в winws2-стратегию ---" -ForegroundColor DarkCyan
    $tcpRanges = @(ConvertTo-PortRanges -Ports @($Results | ForEach-Object { $_.TcpPorts }))
    $udpRanges = @(ConvertTo-PortRanges -Ports @($Results | ForEach-Object { $_.UdpPorts }))
    Write-Host ("  --wf-tcp-out={0}" -f ($tcpRanges -join ',')) -ForegroundColor Green
    Write-Host ("  --wf-udp-out={0}" -f ($udpRanges -join ',')) -ForegroundColor Green
    Write-Host ""
}

# ============================================================================
#  МЕНЮ
# ============================================================================
function Show-PortScannerMenu {
    $defaultDiscord = @(
        'discord.com','discordapp.com','discord.gg','discord.media',
        'cdn.discordapp.com','gateway.discord.gg','updates.discord.com'
    )

    while ($true) {
        Clear-Host
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host "         PORT SCANNER — автоопределение сервиса               " -ForegroundColor Cyan
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host ""

        $listsDir = Get-ListsDir
        if ($listsDir) {
            Write-Host ("  Папка lists/: {0}" -f $listsDir) -ForegroundColor DarkCyan
        } else {
            Write-Host  "  Папка lists/: <не найдена>" -ForegroundColor Red
            Write-Host ("  TxtPath из settings.yml: '{0}'" -f $Global:ZapretState.TxtPath) -ForegroundColor DarkYellow
        }
        Write-Host ""

        Write-Host "  --- быстрый скан (known порты) ---" -ForegroundColor DarkGray
        Write-Host "   1. Discord (встроенный набор)" -ForegroundColor Yellow
        Write-Host "   2. Из lists\ (выбрать .txt-файл)" -ForegroundColor Yellow
        Write-Host "   3. Ввести домены вручную (через запятую)"
        Write-Host "   4. Произвольный путь к .txt-файлу"
        Write-Host "   5. Один домен (без TCP-скана)"
        Write-Host ""
        Write-Host "  --- широкий TCP-скан ---" -ForegroundColor DarkGray
        Write-Host "   6. TCP wide QUICK   (~60 портов)" -ForegroundColor Cyan
        Write-Host "   7. TCP wide STANDARD (~200 портов)" -ForegroundColor Cyan
        Write-Host "   8. TCP FULL 1-65535 (3-5 мин/домен)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  --- UDP-скан ---" -ForegroundColor DarkGray
        Write-Host "   9. UDP STUN probe (только voice-порты сервиса)" -ForegroundColor Cyan
        Write-Host "  10. UDP FULL 1-65535 (10-20 мин/домен)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  --- комбо ---" -ForegroundColor DarkGray
        Write-Host "  11. ПОЛНЫЙ: TCP known + wide STANDARD + UDP probe" -ForegroundColor Yellow
        Write-Host "  12. МАКСИМУМ: TCP FULL + UDP FULL (очень долго)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  13. Сигнатуры сервисов"
        Write-Host "   0. Назад" -ForegroundColor DarkGray
        Write-Host ""
        $c = Read-Host "Номер"

        switch ($c) {

            "1" {
                Write-Host ""
                Write-Host "  Сканирую Discord (known)..." -ForegroundColor Magenta
                $res = @(Invoke-DomainPortScan -Domains $defaultDiscord)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "2" {
                if (-not $listsDir) {
                    Write-Host "`n  [!] Папка lists/ не найдена." -ForegroundColor Red
                    Write-Host ("      TxtPath = '{0}'" -f $Global:ZapretState.TxtPath) -ForegroundColor DarkYellow
                    Write-Host ""; Read-Host "Enter..."; continue
                }
                $files = @(Get-ChildItem -LiteralPath $listsDir -Filter '*.txt' -File -ErrorAction SilentlyContinue | Sort-Object Name)
                if ($files.Count -eq 0) {
                    Write-Host "`n  [!] В папке нет .txt: $listsDir" -ForegroundColor Red
                    Write-Host ""; Read-Host "Enter..."; continue
                }
                Write-Host ""
                Write-Host ("  Файлы в {0}:" -f $listsDir) -ForegroundColor DarkCyan
                Write-Host ""
                $i = 0
                foreach ($f in $files) {
                    $i++
                    $cnt = @(Read-DomainsFromFile -Path $f.FullName).Count
                    Write-Host ("    [{0,2}] {1,-32} ({2} доменов)" -f $i, $f.Name, $cnt)
                }
                Write-Host ""
                Write-Host "    [ 0] Отмена" -ForegroundColor DarkGray
                Write-Host ""
                $sel = (Read-Host "  Номер файла").Trim()
                $n = 0
                if (-not [int]::TryParse($sel, [ref]$n) -or $n -lt 0 -or $n -gt $files.Count) {
                    Write-Host "  [!] Неверный номер" -ForegroundColor Red
                    Write-Host ""; Read-Host "Enter..."; continue
                }
                if ($n -eq 0) { continue }

                $file = $files[$n - 1].FullName
                $domains = @(Read-DomainsFromFile -Path $file)
                if ($domains.Count -eq 0) {
                    Write-Host "`n  [!] В файле нет доменов: $file" -ForegroundColor Red
                    Write-Host ""; Read-Host "Enter..."; continue
                }
                Write-Host ""
                Write-Host ("  Сканирую {0} ({1} доменов)..." -f (Split-Path $file -Leaf), $domains.Count) -ForegroundColor Magenta
                $res = @(Invoke-DomainPortScan -Domains $domains)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "3" {
                $raw = (Read-Host "Домены (через запятую)").Trim()
                if (-not $raw) { continue }
                $list = @($raw -split '[,\s]+' | Where-Object { $_ })
                $res = @(Invoke-DomainPortScan -Domains $list)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "4" {
                $file = (Read-Host "Путь к .txt-файлу").Trim('"').Trim("'")
                if (-not (Test-Path $file)) {
                    Write-Host "  [!] Файл не найден: $file" -ForegroundColor Red
                    Write-Host ""; Read-Host "Enter..."; continue
                }
                $list = @(Read-DomainsFromFile -Path $file)
                if ($list.Count -eq 0) {
                    Write-Host "  [!] Файл пуст или без доменов" -ForegroundColor Red
                    Write-Host ""; Read-Host "Enter..."; continue
                }
                $res = @(Invoke-DomainPortScan -Domains $list)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "5" {
                $d = (Read-Host "Домен").Trim()
                if (-not $d) { continue }
                $res = @(Invoke-DomainPortScan -Domains @($d) -SkipTcpScan)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "6" {
                $raw = (Read-Host "Домены (через запятую, Enter = Discord)").Trim()
                $list = if (-not $raw) { $defaultDiscord } else { @($raw -split '[,\s]+' | Where-Object { $_ }) }
                Write-Host ""
                Write-Host "  TCP WIDE QUICK" -ForegroundColor Magenta
                $res = @(Invoke-DomainPortScan -Domains $list -WideTcp quick)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "7" {
                $raw = (Read-Host "Домены (через запятую, Enter = Discord)").Trim()
                $list = if (-not $raw) { $defaultDiscord } else { @($raw -split '[,\s]+' | Where-Object { $_ }) }
                Write-Host ""
                Write-Host "  TCP WIDE STANDARD" -ForegroundColor Magenta
                $res = @(Invoke-DomainPortScan -Domains $list -WideTcp standard)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "8" {
                $raw = (Read-Host "Домены (через запятую, Enter = Discord)").Trim()
                $list = if (-not $raw) { $defaultDiscord } else { @($raw -split '[,\s]+' | Where-Object { $_ }) }
                Write-Host ""
                Write-Host "  TCP FULL 1-65535 (3-5 мин на домен)" -ForegroundColor Yellow
                $confirm = (Read-Host "  Продолжить? [y/N]").Trim().ToLower()
                if ($confirm -notin @('y','yes','д','да')) { continue }
                $res = @(Invoke-DomainPortScan -Domains $list -WideTcp full)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "9" {
                $raw = (Read-Host "Домены (через запятую, Enter = Discord)").Trim()
                $list = if (-not $raw) { $defaultDiscord } else { @($raw -split '[,\s]+' | Where-Object { $_ }) }
                Write-Host ""
                Write-Host "  UDP STUN PROBE (known voice-порты)" -ForegroundColor Magenta
                $res = @(Invoke-DomainPortScan -Domains $list -UdpProbe)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "10" {
                $raw = (Read-Host "Домены (через запятую, Enter = Discord)").Trim()
                $list = if (-not $raw) { $defaultDiscord } else { @($raw -split '[,\s]+' | Where-Object { $_ }) }
                Write-Host ""
                Write-Host "  UDP FULL 1-65535 (10-20 мин на домен)" -ForegroundColor Yellow
                Write-Host "  ВНИМАНИЕ: 95% портов дадут Timeout — это природа UDP." -ForegroundColor DarkYellow
                $confirm = (Read-Host "  Продолжить? [y/N]").Trim().ToLower()
                if ($confirm -notin @('y','yes','д','да')) { continue }
                $res = @(Invoke-DomainPortScan -Domains $list -UdpFull)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "11" {
                $raw = (Read-Host "Домены (через запятую, Enter = Discord)").Trim()
                $list = if (-not $raw) { $defaultDiscord } else { @($raw -split '[,\s]+' | Where-Object { $_ }) }
                Write-Host ""
                Write-Host "  ПОЛНЫЙ: known + wide STANDARD + UDP STUN probe" -ForegroundColor Yellow
                $res = @(Invoke-DomainPortScan -Domains $list -WideTcp standard -UdpProbe)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "12" {
                $raw = (Read-Host "Домены (через запятую, Enter = Discord)").Trim()
                $list = if (-not $raw) { $defaultDiscord } else { @($raw -split '[,\s]+' | Where-Object { $_ }) }
                Write-Host ""
                Write-Host "  МАКСИМУМ: TCP FULL + UDP FULL" -ForegroundColor Red
                Write-Host "  Один домен = ~15-25 мин. При 7 доменах Discord — ~2-3 часа." -ForegroundColor Red
                Write-Host "  Скан создаст огромный шум. Может ругаться провайдер." -ForegroundColor Red
                $confirm = (Read-Host "  Точно продолжить? Введи 'yes'").Trim()
                if ($confirm -ne 'yes') { continue }
                $res = @(Invoke-DomainPortScan -Domains $list -WideTcp full -UdpFull)
                Show-PortScanSummary -Results $res
                Write-Host ""; Read-Host "Enter..."
            }

            "13" {
                Clear-Host
                Write-Host "  Сигнатуры сервисов" -ForegroundColor Cyan
                Write-Host ""
                foreach ($name in $script:ServiceSignatures.Keys) {
                    $sig = $script:ServiceSignatures[$name]
                    $tcpR = @(ConvertTo-PortRanges -Ports $sig.TcpPorts)
                    $udpR = @(ConvertTo-PortRanges -Ports $sig.UdpPorts)
                    Write-Host ("  [{0}]" -f $name) -ForegroundColor Yellow
                    if ($sig.Patterns.Count) {
                        Write-Host ("    patterns : {0}" -f ($sig.Patterns -join ', ')) -ForegroundColor DarkGray
                    }
                    Write-Host ("    TCP      : {0}" -f ($tcpR -join ',')) -ForegroundColor White
                    Write-Host ("    UDP      : {0}" -f ($udpR -join ',')) -ForegroundColor White
                    if ($sig.ProcessNames.Count) {
                        Write-Host ("    process  : {0}" -f ($sig.ProcessNames -join ', ')) -ForegroundColor DarkGray
                    }
                    Write-Host ""
                }
                Read-Host "Enter..."
            }

            "0" { return }
        }
    }
}