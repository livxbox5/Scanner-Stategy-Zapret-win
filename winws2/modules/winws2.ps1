# ===============================================================
# === WINWS2 (winws2.ps1) — zapret2 / Lua ===
# ===============================================================
#  Функции, специфичные для zapret2:
#    Find-Winws2LuaScripts        — автопоиск zapret-lib.lua / zapret-antidpi.lua
#    Test-Winws2Ready             — проверка winws2.exe + dll + lua
#    Get-Winws2LuaInit            — сборка --lua-init=@...
#    Get-Winws2BlobDefs           — сборка --blob=имя:@путь
#    New-Winws2StrategyCandidates — генерация Lua-стратегий
# ===============================================================


# === RESOLVE-WINWS2LUAPATH ===
# Принимает путь: либо .lua-файл, либо каталог.
# Возвращает полный путь к файлу или $null.
function Resolve-Winws2LuaPath {
    param(
        [string]$Path,
        [string]$TargetName    # 'zapret-lib.lua' / 'zapret-antidpi.lua'
    )

    if (-not $Path) { return $null }

    $Path = $Path.Trim('"').Trim("'")
    $Path = $Path.TrimEnd('\', '/')

    if (-not (Test-Path $Path)) { return $null }

    $item = Get-Item $Path -ErrorAction SilentlyContinue
    if (-not $item) { return $null }

    if ($item.PSIsContainer) {
        # Это каталог — ищем файл внутри
        $candidate = Join-Path $item.FullName $TargetName
        if (Test-Path $candidate) { return (Get-Item $candidate).FullName }
        return $null
    }

    # Это файл — проверяем имя
    if ($item.Name -ieq $TargetName) { return $item.FullName }
    return $null
}

function Find-Winws2LuaScripts {
    param([string]$WinwsPath = $Global:ZapretState.Winws2Path)
    if (-not $WinwsPath) { return }

    $winwsDir = Split-Path $WinwsPath -Parent
    if (-not (Test-Path $winwsDir)) { return }

    $luaDirs = @(
        (Join-Path $winwsDir 'lua'),
        (Join-Path $winwsDir '..\lua'),
        (Join-Path $winwsDir '..\..\lua'),
        $winwsDir
    )

    foreach ($dir in $luaDirs) {
        if (-not (Test-Path $dir)) { continue }
        if (-not $Global:ZapretState.LuaLibPath) {
            $f = Join-Path $dir 'zapret-lib.lua'
            if (Test-Path $f) { $Global:ZapretState.LuaLibPath = $f }
        }
        if (-not $Global:ZapretState.LuaAntiDpiPath) {
            $f = Join-Path $dir 'zapret-antidpi.lua'
            if (Test-Path $f) { $Global:ZapretState.LuaAntiDpiPath = $f }
        }
        if ($Global:ZapretState.LuaLibPath -and $Global:ZapretState.LuaAntiDpiPath) { break }
    }
}

function Test-Winws2Ready {
    param(
        [string]$WinwsPath  = $Global:ZapretState.Winws2Path,
        [string]$LuaLib     = $Global:ZapretState.LuaLibPath,
        [string]$LuaAntiDpi = $Global:ZapretState.LuaAntiDpiPath
    )

    $issues = @()

    if (-not $WinwsPath -or -not (Test-Path $WinwsPath)) {
        $issues += "winws2.exe не найден: $WinwsPath"
    } else {
        $dir = Split-Path $WinwsPath -Parent
        if (-not (Test-Path (Join-Path $dir 'cygwin1.dll')))   { $issues += "Нет cygwin1.dll рядом с winws2.exe" }
        if (-not (Test-Path (Join-Path $dir 'WinDivert.dll'))) { $issues += "Нет WinDivert.dll" }
    }

    # Пробуем развернуть оба пути к реальным .lua-файлам
    $libFile  = Resolve-Winws2LuaPath -Path $LuaLib     -TargetName 'zapret-lib.lua'
    $antiFile = Resolve-Winws2LuaPath -Path $LuaAntiDpi -TargetName 'zapret-antidpi.lua'

    if (-not $libFile)  { $issues += "Не найден zapret-lib.lua (путь: $LuaLib)" }
    if (-not $antiFile) { $issues += "Не найден zapret-antidpi.lua (путь: $LuaAntiDpi)" }

    return [pscustomobject]@{
        Ready  = ($issues.Count -eq 0)
        Issues = $issues
        LibFile  = $libFile
        AntiFile = $antiFile
    }
}

function Get-Winws2LuaInit {
    param(
        [string]$LuaLib     = $Global:ZapretState.LuaLibPath,
        [string]$LuaAntiDpi = $Global:ZapretState.LuaAntiDpiPath
    )

    $libFile  = Resolve-Winws2LuaPath -Path $LuaLib     -TargetName 'zapret-lib.lua'
    $antiFile = Resolve-Winws2LuaPath -Path $LuaAntiDpi -TargetName 'zapret-antidpi.lua'

    $parts = @()
    if ($libFile)  { $parts += "--lua-init=@`"$($libFile  -replace '\\','/')`"" }
    if ($antiFile) { $parts += "--lua-init=@`"$($antiFile -replace '\\','/')`"" }
    return ($parts -join ' ')
}

# Имена blob-ов в winws2 должны быть валидными идентификаторами:
# первая буква/знак_подчёркивания, далее буквы/цифры/_
# 4PDA → B4PDA, 5ka → B5ka, quic-5ka → quic_5ka
function Get-SafeBlobName {
    param([string]$Name)
    if (-not $Name) { return $Name }
    $safe = $Name -replace '[^A-Za-z0-9_]', '_'
    if ($safe -match '^\d') { $safe = "B$safe" }
    return $safe
}

function Get-Winws2BlobDefs {
    param([string]$BinPath = $Global:ZapretState.BinPath)

    if (-not $BinPath -or -not (Test-Path $BinPath)) { return "" }

    $defs = @()
    foreach ($name in $Global:ZapretState.LuaBlobFiles) {
        $file = $Global:ZapretState.LuaBlobFileMap[$name]
        if (-not $file) { continue }
        $full = Join-Path $BinPath $file
        if (Test-Path $full) {
            $safe = Get-SafeBlobName $name
            $defs += "--blob=${safe}:@`"$($full -replace '\\','/')`""
        } else {
            Write-Log "blob-файл не найден: $full" "WARN"
        }
    }
    return ($defs -join ' ')
}

function New-Winws2StrategyCandidates {
    param([string]$TxtDir = $Global:ZapretState.TxtPath)

    $ready = Test-Winws2Ready
    if (-not $ready.Ready) {
        Write-Log "winws2 не готов:" "ERR"
        $ready.Issues | ForEach-Object { Write-Log "  - $_" "ERR" }
        return @()
    }

    $luaInit  = Get-Winws2LuaInit
    $blobDefs = Get-Winws2BlobDefs

    # Глобальная часть: перехват + lua-init + blob-регистрация
    # ВАЖНО: --ctrack НЕ добавляем — в этой сборке такого флага нет.
    $wf = "--wf-tcp-out=443 --wf-tcp-in=443 --wf-udp-out=443 --wf-udp-in=443"
    $globalPart = "$wf $luaInit $blobDefs".Trim()

    # hostlist/hostlist-exclude идут как ПРОФИЛЬНЫЕ фильтры
    $hl = ""; $he = ""
    if ($TxtDir -and (Test-Path $TxtDir)) {
        foreach ($name in @($Global:ZapretState.Hostlist, 'list-general.txt') | Select-Object -Unique) {
            $f = Join-Path $TxtDir $name
            if (Test-Path $f) { $hl = " --hostlist=`"$($f -replace '\\','/')`""; break }
        }
        foreach ($name in @($Global:ZapretState.HostlistExclude, 'list-exclude.txt') | Select-Object -Unique) {
            $f = Join-Path $TxtDir $name
            if (Test-Path $f) { $he = " --hostlist-exclude=`"$($f -replace '\\','/')`""; break }
        }
    }

    # ─── Собираем blob'ы (СЫРЫЕ имена — для method-строки) ───
    $tlsBlobs  = @()
    $quicBlobs = @()

    foreach ($name in $Global:ZapretState.LuaBlobFiles) {
        $file = $Global:ZapretState.LuaBlobFileMap[$name]
        if ($file -match 'tls|clienthello')  { $tlsBlobs  += $name }
        if ($file -match 'quic|initial')     { $quicBlobs += $name }
    }
    if ($tlsBlobs.Count  -eq 0) { $tlsBlobs  = @($Global:ZapretState.LuaBlobs | Where-Object { $_ -match 'tls|clienthello' }) }
    if ($quicBlobs.Count -eq 0) { $quicBlobs = @($Global:ZapretState.LuaBlobs | Where-Object { $_ -match 'quic|initial'   }) }
    if ($tlsBlobs.Count  -eq 0) { $tlsBlobs  = @('fake_default_tls')  }
    if ($quicBlobs.Count -eq 0) { $quicBlobs = @('fake_default_quic') }

    # ─── Списки для перебора ───
    $splits = @(
        '1', '2', 'midsld',
        'method+2',
        'sniext+1',
        'host',
        'host+1',
        'endhost',
        'endhost-1',
        'midsld-2', 'midsld+2',
        '1,sniext+1,host+1,midsld-2,midsld,midsld+2,endhost-1'
    )

    $repeats = @('repeats=1','repeats=2','repeats=4','repeats=6','repeats=8')

    $tlsMods = @(
        'rnd',
        'rnd,rndsni',
        'rnd,dupsid',
        'rnd,dupsid,rndsni',
        'sni=www.google.com',
        'sni=ya.ru'
    )

    $acc = New-Object System.Collections.ArrayList

    # ─── 1. fake + multisplit (TCP/TLS) ───
    foreach ($blobRaw in $tlsBlobs) {
        $blob = Get-SafeBlobName $blobRaw
        foreach ($sp in $splits) {
            foreach ($rep in $repeats) {
                foreach ($tm in $tlsMods) {
                    $fakeParams = "fake:blob=$blob`:tls_mod=$tm`:$rep"
                    $line = "$globalPart --filter-tcp=443 --filter-l7=tls$hl$he --payload=known --lua-desync=$fakeParams --lua-desync=multisplit`:pos=$sp"
                    $method = "fake(blob=$blobRaw,$rep,tls_mod=$tm)+multisplit($sp)"
                    [void]$acc.Add([pscustomobject]@{ Method = $method; Line = $line })
                }
            }
        }
    }

    # ─── 2. fake + multidisorder (TCP/TLS) ───
    foreach ($blobRaw in $tlsBlobs) {
        $blob = Get-SafeBlobName $blobRaw
        foreach ($sp in $splits) {
            foreach ($rep in $repeats) {
                $fakeParams = "fake:blob=$blob`:$rep"
                $line = "$globalPart --filter-tcp=443 --filter-l7=tls$hl$he --payload=known --lua-desync=$fakeParams --lua-desync=multidisorder`:pos=$sp"
                $method = "fake(blob=$blobRaw,$rep)+multidisorder($sp)"
                [void]$acc.Add([pscustomobject]@{ Method = $method; Line = $line })
            }
        }
    }

    # ─── 3. hostfakesplit (TCP/TLS) ───
    foreach ($hname in @('www.google.com','discord.com','www.youtube.com')) {
        $line = "$globalPart --filter-tcp=443 --filter-l7=tls$hl$he --payload=known --lua-desync=hostfakesplit`:host=$hname`:altorder=1"
        [void]$acc.Add([pscustomobject]@{ Method = "hostfakesplit(host=$hname)"; Line = $line })
    }

    # ─── 4. fakeddisorder (TCP/TLS) ───
    foreach ($blobRaw in $tlsBlobs) {
        $blob = Get-SafeBlobName $blobRaw
        foreach ($sp in @('1','2','midsld','host','sniext+1')) {
            $line = "$globalPart --filter-tcp=443 --filter-l7=tls$hl$he --payload=known --lua-desync=fakeddisorder`:blob=$blob`:pos=$sp"
            [void]$acc.Add([pscustomobject]@{ Method = "fakeddisorder(blob=$blobRaw,$sp)"; Line = $line })
        }
    }

    # ─── 5. fake + syndata (TCP/TLS) ───
    foreach ($blobRaw in $tlsBlobs) {
        $blob = Get-SafeBlobName $blobRaw
        $line = "$globalPart --filter-tcp=443 --filter-l7=tls$hl$he --payload=known --lua-desync=fake`:blob=$blob`:repeats=2 --lua-desync=syndata"
        [void]$acc.Add([pscustomobject]@{ Method = "fake(blob=$blobRaw)+syndata"; Line = $line })
    }

    # ─── 6. fake для QUIC (UDP) ───
    foreach ($blobRaw in $quicBlobs) {
        $blob = Get-SafeBlobName $blobRaw
        foreach ($rep in @('repeats=2','repeats=4','repeats=6','repeats=8','repeats=11')) {
            $line = "$globalPart --filter-udp=443 --filter-l7=quic$hl$he --payload=known --lua-desync=fake`:blob=$blob`:$rep"
            [void]$acc.Add([pscustomobject]@{ Method = "quic_fake(blob=$blobRaw,$rep)"; Line = $line })
        }
    }

    # ─── 7. fake для STUN (UDP) ───
    $stunBlobs = @($Global:ZapretState.LuaBlobFiles | Where-Object { $Global:ZapretState.LuaBlobFileMap[$_] -match 'stun' })
    foreach ($blobRaw in $stunBlobs) {
        $blob = Get-SafeBlobName $blobRaw
        $line = "$globalPart --filter-udp=3478,5349 --filter-l7=stun$hl$he --payload=known --lua-desync=fake`:blob=$blob`:repeats=4"
        [void]$acc.Add([pscustomobject]@{ Method = "stun_fake(blob=$blobRaw)"; Line = $line })
    }

    # ─── 8. fake + fakeddisorder (комбо) ───
    foreach ($blobRaw in $tlsBlobs) {
        $blob = Get-SafeBlobName $blobRaw
        foreach ($sp in @('midsld','sniext+1')) {
            $line = "$globalPart --filter-tcp=443 --filter-l7=tls$hl$he --payload=known --lua-desync=fake`:blob=$blob`:repeats=2 --lua-desync=fakeddisorder`:pos=$sp"
            [void]$acc.Add([pscustomobject]@{ Method = "fake(blob=$blobRaw)+fakeddisorder($sp)"; Line = $line })
        }
    }

    $totalGenerated = $acc.Count
    $randomCount = 0
    $rawRc = $Global:ZapretState.RandomCount
    if ($null -ne $rawRc) {
        $parsed = 0
        if ([int]::TryParse("$rawRc", [ref]$parsed)) { $randomCount = $parsed }
    }

    Write-Log ("[winws2] Сгенерировано {0} стратегий (RandomCount={1})" -f $totalGenerated, $randomCount) "INFO"

    if ($randomCount -gt 0 -and $totalGenerated -gt $randomCount) {
        return @($acc.ToArray() | Get-Random -Count $randomCount)
    }
    return @($acc.ToArray())
}