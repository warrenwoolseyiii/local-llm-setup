@echo off
REM ============================================================================
REM setup-ai-rules.bat — Apply unified AI rules (RTK + terse/caveman) to all coding agents.
REM
REM Usage:
REM   setup-ai-rules.bat              — Apply to current project (local, copy mode)
REM   setup-ai-rules.bat --global     — Apply to global agent configs
REM   setup-ai-rules.bat --uninstall  — Remove copies from current project
REM   setup-ai-rules.bat --global --uninstall — Remove from global configs
REM
REM Supports: Claude Code, Cline/Roo Code, Cursor, Windsurf, GitHub Copilot, Codex, Continue
REM NOTE: .bat cannot create symlinks; always copies files.
REM ============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "RULES_SOURCE=%SCRIPT_DIR%\.ai-rules.md"

set "MODE=local"
set "UNINSTALL=0"

REM --- Parse arguments --------------------------------------------------------
:parse_args
if "%~1"=="" goto :done_args
if /i "%~1"=="--global" (
    set "MODE=global"
    shift
    goto :parse_args
)
if /i "%~1"=="--uninstall" (
    set "UNINSTALL=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--copy" (
    REM Always copy on bat, this is a no-op
    shift
    goto :parse_args
)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
echo Unknown option: %~1
exit /b 1
:done_args

REM --- Check rules source exists ----------------------------------------------
if "%UNINSTALL%"=="0" (
    if not exist "%RULES_SOURCE%" (
        echo ERROR: Rules source not found: %RULES_SOURCE%
        echo Expected .ai-rules.md in same directory as this script.
        exit /b 1
    )
)

echo.

REM --- Local mode -------------------------------------------------------------
if "%MODE%"=="local" (
    set "PROJECT_DIR=%CD%"
    echo Project: !PROJECT_DIR!
    echo Source:  %RULES_SOURCE%
    echo.

    if "%UNINSTALL%"=="1" (
        echo Removing AI rules from project...
        call :process_target "!PROJECT_DIR!\.clinerules" remove
        call :process_target "!PROJECT_DIR!\.cursorrules" remove
        call :process_target "!PROJECT_DIR!\.windsurfrules" remove
        call :process_target "!PROJECT_DIR!\CLAUDE.md" remove
        call :process_target "!PROJECT_DIR!\AGENTS.md" remove
        call :process_target "!PROJECT_DIR!\.continuerules" remove
        call :process_target "!PROJECT_DIR!\.github\copilot-instructions.md" remove
    ) else (
        echo Applying AI rules to project...
        call :copy_target "!PROJECT_DIR!\.clinerules"
        call :copy_target "!PROJECT_DIR!\.cursorrules"
        call :copy_target "!PROJECT_DIR!\.windsurfrules"
        call :copy_target "!PROJECT_DIR!\CLAUDE.md"
        call :copy_target "!PROJECT_DIR!\AGENTS.md"
        call :copy_target "!PROJECT_DIR!\.continuerules"
        call :copy_target "!PROJECT_DIR!\.github\copilot-instructions.md"
    )
    goto :finish
)

REM --- Global mode ------------------------------------------------------------
if "%MODE%"=="global" (
    echo Applying AI rules globally...
    echo Source: %RULES_SOURCE%
    echo.

    if "%UNINSTALL%"=="1" (
        echo Removing global AI rules...
        echo   [cline]
        call :process_target "%USERPROFILE%\.cline\rules" remove
        echo   [roo]
        call :process_target "%USERPROFILE%\.roo\rules" remove
        echo   [claude]
        call :process_target "%USERPROFILE%\.claude\CLAUDE.md" remove
    ) else (
        echo   [cline]
        call :copy_target "%USERPROFILE%\.cline\rules"
        echo   [roo]
        call :copy_target "%USERPROFILE%\.roo\rules"
        echo   [claude]
        call :copy_target "%USERPROFILE%\.claude\CLAUDE.md"
    )
    goto :finish
)

:finish
echo.
echo Done.
exit /b 0

REM ============================================================================
REM Subroutines
REM ============================================================================

:copy_target
REM Copy rules source to target, creating parent dir if needed
set "TARGET=%~1"
for %%I in ("%TARGET%") do set "TARGET_DIR=%%~dpI"
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if exist "%TARGET%" del /f /q "%TARGET%"
copy /y "%RULES_SOURCE%" "%TARGET%" >nul
echo   ✓ copied:    %TARGET%
goto :eof

:process_target
REM Remove target file (uninstall mode)
REM NOTE: .bat cannot do content-diff safety check like .sh/.ps1.
REM       It removes the file unconditionally if it exists.
set "TARGET=%~1"
if exist "%TARGET%" (
    del /f /q "%TARGET%"
    echo   ✗ removed: %TARGET%
) else (
    echo   - not present: %TARGET%
)
goto :eof

:show_help
echo Usage: %~nx0 [--global] [--uninstall] [--copy]
echo.
echo   (no flags)    Apply rules to current project directory (copy)
echo   --copy        No-op on .bat (always copies)
echo   --global      Apply rules to global agent config directories
echo   --uninstall   Remove previously applied rules
exit /b 0
