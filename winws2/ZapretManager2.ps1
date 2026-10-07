# ===============================================================
# === ZAPRET MANAGER 2 (winws2.exe / Lua) ===
# ===============================================================
#  Точка входа для zapret2. Подключает модули, показывает меню.
#  Работает ТОЛЬКО с winws2.exe + Lua.
# ===============================================================

# === ПОДКЛЮЧЕНИЕ МОДУЛЕЙ ===
. "$PSScriptRoot\modules\Core.ps1"
. "$PSScriptRoot\modules\Settings.ps1"
. "$PSScriptRoot\modules\FileScanner.ps1"
. "$PSScriptRoot\modules\StrategyTester.ps1"
. "$PSScriptRoot\modules\Dns.ps1"
. "$PSScriptRoot\modules\DnsDoH.ps1"
. "$PSScriptRoot\modules\Launcher.ps1"
. "$PSScriptRoot\modules\Provider.ps1"
. "$PSScriptRoot\modules\Verify.ps1"
. "$PSScriptRoot\modules\winws2.ps1"

# === ЗАГРУЗКА НАСТРОЕК ===
Import-Settings

# === АВТО-ПОИСК LUA ===
Find-Winws2LuaScripts

# === АВТО-ДЕТЕКТ ПРОВАЙДЕРА ===
$Global:ProviderContext = Show-ProviderInfo

# === ПРОВЕРКА ПРАВ АДМИНИСТРАТОРА ===
if (-not (Test-Admin)) {
    Write-Host ""
    Write-Host "!! Запущено без прав администратора. winws2 не сможет стартовать." -ForegroundColor Yellow
    Write-Host "   Рекомендуется: правый клик → 'Запуск от имени администратора'." -ForegroundColor Yellow
    Read-Host "`nНажмите Enter для продолжения..."
}

# ===============================================================
# === МЕНЮ ===
# ===============================================================
function Show-Menu {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║                 ZAPRET MANAGER 2                             ║" -ForegroundColor Magenta
    Write-Host "║                 (winws2.exe / Lua)                            ║" -ForegroundColor DarkMagenta
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "  Текущие пути:" -ForegroundColor DarkMagenta
    Write-Host ("    winws2.exe  : {0}" -f $(if ($Global:ZapretState.Winws2Path) { $Global:ZapretState.Winws2Path } else { "<не задан>" }))
    Write-Host ("    LuaLib      : {0}" -f $(if ($Global:ZapretState.LuaLibPath) { $Global:ZapretState.LuaLibPath } else { "<не задан>" }))
    Write-Host ("    LuaAntiDpi  : {0}" -f $(if ($Global:ZapretState.LuaAntiDpiPath) { $Global:ZapretState.LuaAntiDpiPath } else { "<не задан>" }))
    Write-Host ("    TxtPath     : {0}" -f $(if ($Global:ZapretState.TxtPath) { $Global:ZapretState.TxtPath } else { "<не задан>" }))
    Write-Host ("    BinPath     : {0}" -f $(if ($Global:ZapretState.BinPath) { $Global:ZapretState.BinPath } else { "<не задан>" }))
    Write-Host ("    HTTP-tool   : {0}" -f $Global:ZapretState.Tool)
    Write-Host ("    MaxDomains  : {0}" -f $(if ($Global:ZapretState.MaxDomains -eq 0) { "без лимита" } else { $Global:ZapretState.MaxDomains }))
    Write-Host ("    Lua ready   : {0}" -f $(if ($Global:ZapretState.LuaReady) { "ДА" } else { "НЕТ" })) -ForegroundColor $(if ($Global:ZapretState.LuaReady) { "Green" } else { "Red" })
    Show-ZapretStatus
    Write-Host ""

    # ─── 1-5: Пути ───
    Write-Host "  ─── Пути ──────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   1. Путь к winws2.exe"
    Write-Host "   2. Путь к zapret-lib.lua"
    Write-Host "   3. Путь к zapret-antidpi.lua"
    Write-Host "   4. Путь к .txt (hostlist)"
    Write-Host "   5. Путь к .bin (blob-файлы)"
    Write-Host ""

    # ─── 6-10: Поиск файлов ───
    Write-Host "  ─── Поиск файлов ──────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   6. Найти все .txt и .bin и .Lua"
    Write-Host "   7. Найти только .txt"
    Write-Host "   8. Найти только .bin"
    Write-Host "   9. Найти .txt + показать содержимое"
    Write-Host "  10. Найти только .lua" -ForegroundColor Cyan
    Write-Host ""

    # ─── 11-15: Стратегии ───
    Write-Host "  ─── Стратегии ─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  11. АВТО-ТЕСТ стратегий (Lua)" -ForegroundColor Yellow
    Write-Host "  12. Показать загруженные стратегии"
    Write-Host "  13. Выбрать и запустить стратегию"
    Write-Host "  14. Остановить winws2"
    Write-Host "  15. Показать resultats\resultat.txt"
    Write-Host ""

    # ─── 16-20: Диагностика ───
    Write-Host "  ─── Диагностика ───────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  16. Проверить один сайт (без winws2)"
    Write-Host "  17. Проверить текущее соединение"
    Write-Host "  18. Сменить HTTP-инструмент (auto/curl/wget/iwr)"
    Write-Host "  19. Показать домены из hostlist"
    Write-Host "  20. Показать HTTP-инструменты"
    Write-Host ""

    # ─── 21-23: Сеть / DNS ───
    Write-Host "  ─── Сеть ──────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  21. DNS-серверы (UDP)" -ForegroundColor Magenta
    Write-Host "  22. DNS-over-HTTPS (DoH)" -ForegroundColor Magenta
    Write-Host "  23. Настройки тестирования (settings.yml)" -ForegroundColor Magenta
    Write-Host ""

    # ─── 24-27: Провайдер ───
    Write-Host "  ─── Провайдер ─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  24. Показать информацию о провайдере"
    Write-Host "  25. УМНЫЙ ПОДБОР под провайдера" -ForegroundColor Yellow
    Write-Host "  26. Обновить данные о провайдере"
    Write-Host "  27. Очистить базу стратегий провайдера"
    Write-Host ""

    # ─── 28-29: Проверка результатов ───
    Write-Host "  ─── Проверка результатов ──────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  28. Статистика resultats\ (pretest + resultat)"
    Write-Host "  29. ПЕРЕПРОВЕРИТЬ стратегии (промоут pretest -> resultat)" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "   0. Выход" -ForegroundColor DarkGray
    Write-Host ""
}

# ===============================================================
# === ГЛАВНЫЙ ЦИКЛ ===
# ===============================================================
while ($true) {
    Show-Menu
    $choice = Read-Host "Выберите пункт"

    switch ($choice) {
        # ─── 1-5: Пути ───
        "1"  { Set-Winws2Path }
        "2"  { Set-LuaLibPath }
        "3"  { Set-LuaAntiDpiPath }
        "4"  { Set-TxtPath }
        "5"  { Set-BinPath }

        # ─── 6-10: Поиск ───
        "6"  {
            Find-AllFiles -RootPath $Global:ZapretState.TxtPath | Out-Null
            Find-AllFiles -RootPath $Global:ZapretState.BinPath | Out-Null
        }
        "7"  { Find-AllFiles -RootPath $Global:ZapretState.TxtPath -OnlyTxt | Out-Null }
        "8"  { Find-AllFiles -RootPath $Global:ZapretState.BinPath -OnlyBin | Out-Null }
        "9"  { Find-AllFiles -RootPath $Global:ZapretState.TxtPath -OnlyTxt -ShowContent | Out-Null }
        "10" {
            $luaDir = Split-Path $Global:ZapretState.LuaLibPath -Parent
            if ($luaDir -and (Test-Path $luaDir)) {
                Find-AllFiles -RootPath $luaDir -OnlyLua | Out-Null
            } else {
                Write-Log "LuaLibPath не задан — не могу определить папку с .lua" "ERR"
            }
        }

        # ─── 11-15: Стратегии ───
        "11" {
            $scanResult = Invoke-StrategyScan
            if ($scanResult -and $scanResult.Count -gt 0 -and $Global:ProviderContext) {
                $saved = 0
                foreach ($r in $scanResult) {
                    if ($r.Score -gt 0) {
                        Save-ProviderStrategy -ProfileName $Global:ProviderContext.Profile `
                            -Strategy $r.Strategy -Score $r.Score -Total $r.Total
                        $saved++
                    }
                }
                if ($saved -gt 0) {
                    Write-Log ("Сохранено в базу '{0}': {1} стратегий" -f $Global:ProviderContext.Profile, $saved) "INFO"
                }
            }
        }
        "12" {
            if ($Global:ZapretState.Strategies.Count -eq 0) {
                Write-Log "Стратегий нет. Сначала пункт 11." "WARN"
            } else {
                $i = 0
                foreach ($s in $Global:ZapretState.Strategies) {
                    $i++
                    Write-Host ("  [{0}] {1}" -f $i, $s)
                }
            }
        }
        "13" {
            if ($Global:ZapretState.Strategies.Count -eq 0) {
                Write-Log "Стратегий нет. Сначала пункт 11." "WARN"
            } else {
                $i = 0
                foreach ($s in $Global:ZapretState.Strategies) {
                    $i++
                    Write-Host ("  [{0}] {1}" -f $i, $s)
                }
                Write-Host ""
                $sel = Read-Host "Номер стратегии (Enter — последняя)"
                if ([string]::IsNullOrWhiteSpace($sel)) {
                    Start-Zapret -StrategyLine $Global:ZapretState.Strategies[-1]
                } else {
                    $n = 0
                    if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le $Global:ZapretState.Strategies.Count) {
                        Start-Zapret -StrategyLine $Global:ZapretState.Strategies[$n - 1]
                    } else {
                        Write-Log "Неверный номер" "ERR"
                    }
                }
            }
        }
        "14" { Stop-Zapret }
        "15" { Show-ResultFile }

        # ─── 16-20: Диагностика ───
        "16" { Test-SingleSite }
        "17" { Test-CurrentConnection }
        "18" { Set-HttpTool }
        "19" { Edit-TestDomains }
        "20" { Show-HttpToolStatus }

        # ─── 21-23: Сеть ───
        "21" { Show-DnsMenu }
        "22" { Show-DohMenu }
        "23" { Show-TestSettings }

        # ─── 24-27: Провайдер ───
        "24" { Show-ProviderInfo | Out-Null }
        "25" { Invoke-SmartProviderRun }
        "26" { Update-ProviderCache }
        "27" { Clear-ProviderDb }

        # ─── 28-29: Проверка результатов ───
        "28" { Show-ResultsStats }
        "29" { Invoke-VerifyScan }

        "0"  { break }
        default { Write-Log "Неверный пункт" "ERR" }
    }

    if ($choice -eq "0") { break }

    Write-Host ""
    Read-Host "Нажмите Enter для возврата в меню"
}