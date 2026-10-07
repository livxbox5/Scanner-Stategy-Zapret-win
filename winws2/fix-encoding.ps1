# ===============================================================
# === FIX-ENCODING (fix-encoding.ps1) — winws2 ===
# ===============================================================
#  Normalizes BOM in all project .ps1 files.
#
#  What it does:
#    1. Eats ALL leading BOMs (EF BB BF) including double/triple.
#    2. Leaves exactly ONE BOM.
#
#  Why:
#    - PowerShell 5.1 on Russian Windows reads UTF-8 without BOM
#      as CP1251 and breaks Russian comments parsing.
#    - Double BOM (EF BB BF EF BB BF): PS eats the first one, the
#      second becomes U+FEFF at the start of the line, so '#' is
#      no longer first char and the script fails with
#      CommandNotFoundException.
#
#  Params:
#    -Quiet  do not print [OK] lines and do not wait for Enter.
#            Used when called from start2.bat.
#
#  This file is intentionally pure-ASCII, because it must run
#  even when its own encoding is broken (no BOM). It fixes itself
#  on the first run.
# ===============================================================

param([switch]$Quiet)

# === FILE LIST ===
$Root = $PSScriptRoot

$files = @()
$files += Get-ChildItem -Path (Join-Path $Root 'modules') -Filter '*.ps1' -ErrorAction SilentlyContinue
$files += Get-Item (Join-Path $Root 'ZapretManager2.ps1') -ErrorAction SilentlyContinue
$files += Get-Item (Join-Path $Root 'fix-encoding.ps1')   -ErrorAction SilentlyContinue

$oneBom  = [byte[]](0xEF, 0xBB, 0xBF)
$fixed   = 0
$okCount = 0

# === FIX LOOP ===
foreach ($f in $files) {
    if (-not $f) { continue }

    $bytes  = [System.IO.File]::ReadAllBytes($f.FullName)
    $i      = 0
    $hadBom = $false

    # Eat ALL leading BOM sequences
    while ($i + 2 -lt $bytes.Length -and
           $bytes[$i]     -eq 0xEF -and
           $bytes[$i + 1] -eq 0xBB -and
           $bytes[$i + 2] -eq 0xBF) {
        $hadBom = $true
        $i += 3
    }

    if ($i -eq 0) {
        # No BOM at all -> add exactly one
        $new = $oneBom + $bytes
        [System.IO.File]::WriteAllBytes($f.FullName, $new)
        Write-Host "  [ADD]  $($f.Name)  (BOM added)" -ForegroundColor Yellow
        $fixed++
        continue
    }

    # Body without leading BOMs
    $body = if ($i -lt $bytes.Length) { $bytes[$i..($bytes.Length - 1)] } else { @() }

    # Leave exactly one BOM
    $new = $oneBom + $body

    if ($i -eq 3) {
        if (-not $Quiet) {
            Write-Host "  [OK]   $($f.Name)" -ForegroundColor DarkGray
        }
        $okCount++
    } else {
        [System.IO.File]::WriteAllBytes($f.FullName, $new)
        Write-Host "  [FIX]  $($f.Name)  (BOM x$([int]($i / 3)) -> 1)" -ForegroundColor Yellow
        $fixed++
    }
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host ("  Done. Fixed: {0}, already OK: {1}" -f $fixed, $okCount) -ForegroundColor Magenta
    Write-Host "  Run ZapretManager2.ps1 as admin." -ForegroundColor Magenta
    Write-Host ""
    Read-Host "  Enter..."
} elseif ($fixed -gt 0) {
    Write-Host ("  [fix-encoding] Fixed files: {0}" -f $fixed) -ForegroundColor Yellow
}