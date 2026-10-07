# ===============================================================
# === ГЛАВНЫЙ ФАЙЛ (ZapretManager.ps1) ===
# ===============================================================
#  Точка входа. Подключает все модули, показывает меню, обрабатывает выбор.
#  Работает ТОЛЬКО с zapret1 (winws.exe).
#
#  Меню:
#    1-3   пути                            -> Settings.ps1
#    4-7   поиск файлов                    -> FileScanner.ps1
#    8-12  авто-тест, стратегии            -> StrategyTester.ps1
#    13-17 диагностика                     -> StrategyTester.ps1
#    18-20 DNS/DoH/settings                -> Dns.ps1, DnsDoH.ps1
#    21-24 провайдер (умный подбор)        -> Provider.ps1
#    25-26 проверка и промоут              -> Verify.ps1
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
. "$PSScriptRoot\modules\CheckStrategy.ps1" 

# === ЗАГРУЗКА НАСТРОЕК ===
Load-Settings

# === АВТО-ДЕТЕКТ ПРОВАЙДЕРА ===
$Global:ProviderContext = Show-ProviderInfo

# === ПРОВЕРКА ПРАВ АДМИНИСТРАТОРА ===
if (-not (Test-Admin)) {
    Write-Host ""
    Write-Host "!! Запущено без прав администратора. winws не сможет стартовать." -ForegroundColor Yellow
    Write-Host "   Рекомендуется: правый клик → 'Запуск от имени администратора'." -ForegroundColor Yellow
    Read-Host "`nНажмите Enter для продолжения..."
}

# ===============================================================
# === МЕНЮ (Show-Menu) ===
# ===============================================================
function Show-Menu {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    ZAPRET MANAGER                            ║" -ForegroundColor Cyan
    Write-Host "║                    (только winws.exe)                        ║" -ForegroundColor DarkCyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Текущие пути:" -ForegroundColor DarkCyan
    Write-Host ("    exe         : {0}" -f $(if ($Global:ZapretState.WinwsPath) { $Global:ZapretState.WinwsPath } else { "<не задан>" }))
    Write-Host ("    .txt        : {0}" -f $(if ($Global:ZapretState.TxtPath)   { $Global:ZapretState.TxtPath   } else { "<не задан>" }))
    Write-Host ("    .bin        : {0}" -f $(if ($Global:ZapretState.BinPath)   { $Global:ZapretState.BinPath   } else { "<не задан>" }))
    Write-Host ("    HTTP-tool   : {0}" -f $Global:ZapretState.Tool)
    Write-Host ("    MaxDomains  : {0}" -f $(if ($Global:ZapretState.MaxDomains -eq 0) { "без лимита" } else { $Global:ZapretState.MaxDomains }))
    Write-Host ("    DNS-pool    : {0} шт. (UDP)" -f $Global:ZapretState.DnsServers.Count)
    Write-Host ("    DoH-pool    : {0} шт." -f $Global:ZapretState.DohServers.Count)
    Show-ZapretStatus
    Write-Host ""

    # ─── 1-3: Пути ───
    Write-Host "  ─── Пути ──────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   1. Путь к winws.exe"
    Write-Host "   2. Путь к .txt (hostlist)"
    Write-Host "   3. Путь к .bin (fake payloads)"
    Write-Host ""

    # ─── 4-7: Поиск файлов ───
    Write-Host "  ─── Поиск файлов ──────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   4. Найти все .txt и .bin"
    Write-Host "   5. Найти только .txt"
    Write-Host "   6. Найти только .bin"
    Write-Host "   7. Найти .txt + показать содержимое"
    Write-Host ""

    # ─── 8-12: Стратегии ───
    Write-Host "  ─── Стратегии ─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   8. АВТО-ТЕСТ стратегий (без ограничений)" -ForegroundColor Yellow
    Write-Host "   9. Показать загруженные стратегии"
    Write-Host "  10. Выбрать и запустить стратегию"
    Write-Host "  11. Остановить winws"
    Write-Host "  12. Показать resultats\resultat.txt"
    Write-Host ""

    # ─── 13-17: Диагностика ───
    Write-Host "  ─── Диагностика ───────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  13. Проверить один сайт (без winws)"
    Write-Host "  14. Проверить текущее соединение"
    Write-Host "  15. Сменить HTTP-инструмент (auto/curl/wget/iwr)"
    Write-Host "  16. Показать домены из hostlist"
    Write-Host "  17. Показать HTTP-инструменты"
    Write-Host ""

    # ─── 18-20: Сеть / DNS ───
    Write-Host "  ─── Сеть ──────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  18. DNS-серверы (UDP)" -ForegroundColor Magenta
    Write-Host "  19. DNS-over-HTTPS (DoH)" -ForegroundColor Magenta
    Write-Host "  20. Настройки тестирования (settings.yml)" -ForegroundColor Cyan
    Write-Host ""

    # ─── 21-24: Провайдер ───
    Write-Host "  ─── Провайдер ─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  21. Показать информацию о провайдере"
    Write-Host "  22. УМНЫЙ ПОДБОР под провайдера" -ForegroundColor Yellow
    Write-Host "  23. Обновить данные о провайдере"
    Write-Host "  24. Очистить базу стратегий провайдера"
    Write-Host ""

    # ─── 25-27: Проверка результатов ───
    Write-Host "  ─── Проверка результатов ──────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  25. Статистика resultats\ (pretest + resultat)"
    Write-Host "  26. ПЕРЕПРОВЕРИТЬ стратегии (промоут pretest -> resultat)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ─── Готовые .bat ──────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  27. ПРОВЕРИТЬ СТРАТЕГИИ ИЗ .BAT (что открывают)" -ForegroundColor Yellow
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
        # ─── 1-3: Пути ───
        "1"  { Set-WinwsPath }
        "2"  { Set-TxtPath }
        "3"  { Set-BinPath }

        # ─── 4-7: Поиск ───
        "4"  {
            Find-AllFiles -RootPath $Global:ZapretState.TxtPath | Out-Null
            Find-AllFiles -RootPath $Global:ZapretState.BinPath | Out-Null
        }
        "5"  { Find-AllFiles -RootPath $Global:ZapretState.TxtPath -OnlyTxt | Out-Null }
        "6"  { Find-AllFiles -RootPath $Global:ZapretState.BinPath -OnlyBin | Out-Null }
        "7"  { Find-AllFiles -RootPath $Global:ZapretState.TxtPath -OnlyTxt -ShowContent | Out-Null }

        # ─── 8-12: Стратегии ───
        "8" {
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

        "9" {
            if ($Global:ZapretState.Strategies.Count -eq 0) {
                Write-Log "Стратегий нет. Сначала пункт 8." "WARN"
            } else {
                $i = 0
                foreach ($s in $Global:ZapretState.Strategies) {
                    $i++
                    Write-Host ("  [{0}] {1}" -f $i, $s)
                }
            }
        }

        "10" {
            if ($Global:ZapretState.Strategies.Count -eq 0) {
                Write-Log "Стратегий нет. Сначала пункт 8." "WARN"
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

        "11" { Stop-Zapret }
        "12" { Show-ResultFile }

        # ─── 13-17: Диагностика ───
        "13" { Test-SingleSite }
        "14" { Test-CurrentConnection }
        "15" { Set-HttpTool }
        "16" { Edit-TestDomains }
        "17" { Show-HttpToolStatus }

        # ─── 18-20: Сеть ───
        "18" { Show-DnsMenu }
        "19" { Show-DohMenu }
        "20" { Show-TestSettings }

        # ─── 21-24: Провайдер ───
        "21" { Show-ProviderInfo | Out-Null }
        "22" { Invoke-SmartProviderRun }
        "23" { Update-ProviderCache }
        "24" { Clear-ProviderDb }

        # ─── 25-26: Проверка результатов ───
        "25" { Show-ResultsStats }
        "26" { Invoke-VerifyScan }
        "27" { Show-CheckStrategyMenu }

        "0"  { break }
        default { Write-Log "Неверный пункт" "ERR" }
    }

    if ($choice -eq "0") { break }

    Write-Host ""
    Read-Host "Нажмите Enter для возврата в меню"
}