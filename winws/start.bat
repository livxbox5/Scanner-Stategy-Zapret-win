@echo off
chcp 65001 > nul
title Zapret Manager

:: ─── Авто-повышение прав до администратора ───────────────────
net session >nul 2>&1
if errorlevel 1 (
    echo Запрос прав администратора...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:: ─── Нормализация BOM во всех .ps1 (тихо) ───────────────────
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix-encoding.ps1" -Quiet
if errorlevel 1 (
    echo.
    echo [!] fix-encoding.ps1 завершился с ошибкой.
    pause
    exit /b 1
)

:: ─── Запуск главного менеджера ──────────────────────────────
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ZapretManager.ps1"
if errorlevel 1 (
    echo.
    echo [!] ZapretManager.ps1 завершился с ошибкой.
    pause
    exit /b 1
)