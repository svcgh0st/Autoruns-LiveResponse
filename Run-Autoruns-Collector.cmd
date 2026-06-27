@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "OUTPUT_DIR=%SCRIPT_DIR%results"

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo Autoruns portable collector
echo.
echo Press Enter for the default scan:
echo   [1] Triage: recent 30 days, hide Microsoft-signed entries, drop empty rows
echo.
echo Other options:
echo   [2] Recent 30 days, full/noisy
echo   [3] Unsigned entries only
echo   [4] Normal full Autoruns CSV
echo.
set /p "CHOICE=Choose 1, 2, 3, or 4 [default 1]: "
if "%CHOICE%"=="" set "CHOICE=1"

set "MODE=triage-recent30"
set "ARGS=-RecentDays 30 -SignatureFilter All -HideMicrosoft -DropEmptyRows"

if "%CHOICE%"=="2" (
    set "MODE=recent30-full"
    set "ARGS=-RecentDays 30 -SignatureFilter All"
)

if "%CHOICE%"=="3" (
    set "MODE=unsigned"
    set "ARGS=-SignatureFilter Unsigned"
)

if "%CHOICE%"=="4" (
    set "MODE=full"
    set "ARGS=-SignatureFilter All"
)

set "STAMP=%DATE:/=-%_%TIME::=-%"
set "STAMP=%STAMP: =0%"
set "OUTPUT_CSV=%OUTPUT_DIR%\autoruns-%MODE%-%COMPUTERNAME%-%STAMP%.csv"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Export-Autoruns.ps1" %ARGS% -IgnoreFile "%SCRIPT_DIR%autoruns-ignore.txt" -OutputCsv "%OUTPUT_CSV%"

echo.
echo Output saved to:
echo %OUTPUT_CSV%
echo.
pause
