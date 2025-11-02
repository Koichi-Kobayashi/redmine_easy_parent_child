@echo off
REM Redmine Easy Parent Child Plugin - Package script
REM This batch file executes the PowerShell script

REM Set UTF-8 code page to display Japanese characters correctly
chcp 65001 >nul 2>&1

setlocal

REM Get version from argument (default: 1.0.0)
set VERSION=%1
if "%VERSION%"=="" set VERSION=1.0.0

REM Get output directory from argument (default: current directory)
set OUTPUT_DIR=%2
if "%OUTPUT_DIR%"=="" set OUTPUT_DIR=.

echo ========================================
echo Redmine Easy Parent Child Plugin
echo Packaging Script
echo ========================================
echo.

REM Change to this batch file's directory
cd /d "%~dp0"

REM Execute PowerShell script with UTF-8 encoding
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8; chcp 65001 | Out-Null; & '%~dp0package.ps1' -Version '%VERSION%' -OutputDir '%OUTPUT_DIR%'"

if %ERRORLEVEL% neq 0 (
    echo.
    echo Error: Packaging failed.
    pause
    exit /b 1
)

echo.
pause

