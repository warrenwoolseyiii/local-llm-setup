@echo off
chcp 65001 >nul
REM ============================================================================
REM setup-coding-env.bat — Master setup for token-optimized coding environment.
REM
REM Checks for and optionally installs: CodeGraph, RTK, Caveman, Continue.
REM Applies AI rules (RTK + caveman/terse) to all agent config files.
REM
REM Usage:
REM   setup-coding-env.bat           — Interactive setup
REM   setup-coding-env.bat --help    — Show help
REM
REM NOTE: .bat has limited interactive capability compared to .sh/.ps1.
REM       Some installers (CodeGraph, RTK) require manual steps on Windows.
REM ============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "RULES_SOURCE=%SCRIPT_DIR%\.ai-rules.md"
set "SEPARATOR=# --- Token Efficiency Rules (auto-appended by setup-coding-env.bat) ---"

REM --- Parse arguments --------------------------------------------------------
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help

echo.
echo ╔═══════════════════════════════════════════════════════════════╗
echo ║        Token-Optimized Coding Environment Setup              ║
echo ╚═══════════════════════════════════════════════════════════════╝
echo.

REM ===========================================================================
REM 1. CodeGraph
REM ===========================================================================
call :header "CodeGraph"
where codegraph >nul 2>&1
set "CG_FOUND=!errorlevel!"
if "!CG_FOUND!"=="0" (
    echo ✓  CodeGraph already installed.
    call :prompt_codegraph_init
) else (
    echo ⚠  CodeGraph not found.
    set /p "CG_INSTALL=?  Install CodeGraph? (codebase analysis tool) [y/N] "
    if /i "!CG_INSTALL!"=="y" (
        echo i  Attempting to install CodeGraph...
        npm i -g @colbymchenry/codegraph
        REM Check if CodeGraph was installed successfully
        where codegraph >nul 2>&1
        if !errorlevel!==0 (
            echo ✓  CodeGraph installed successfully.
            call :prompt_codegraph_init
        ) else (
            echo ⚠  CodeGraph not on PATH. Install manually.
            echo    See: https://github.com/colbymchenry/codegraph
        )
    ) else (
        echo i  Skipping CodeGraph.
    )
)

REM ===========================================================================
REM 2. RTK
REM ===========================================================================
call :header "RTK (Rust Token Killer)"
where rtk >nul 2>&1
set "RTK_FOUND=!errorlevel!"
if "!RTK_FOUND!"=="0" (
    echo ✓  RTK already installed.
    call :prompt_rtk_init
) else (
    echo ⚠  RTK not found.
    set /p "RTK_INSTALL=?  Install RTK? (CLI proxy for token savings) [y/N] "
    if /i "!RTK_INSTALL!"=="y" (
        set "RTK_RELEASE_URL=https://github.com/rtk-ai/rtk/releases/latest/download/rtk-x86_64-pc-windows-msvc.zip"
        set "RTK_ZIP=%TEMP%\rtk-windows.zip"
        set "RTK_EXTRACT=%TEMP%\rtk-extract"
        set "RTK_BIN=%USERPROFILE%\.local\bin"
        echo i  Downloading RTK from GitHub releases...
        powershell -NoProfile -Command "Invoke-WebRequest -Uri '!RTK_RELEASE_URL!' -OutFile '!RTK_ZIP!' -UseBasicParsing"
        if !errorlevel!==0 (
            echo i  Extracting RTK...
            if not exist "!RTK_BIN!" mkdir "!RTK_BIN!"
            powershell -NoProfile -Command "Expand-Archive -Path '!RTK_ZIP!' -DestinationPath '!RTK_EXTRACT!' -Force; Copy-Item '!RTK_EXTRACT!\rtk.exe' '!RTK_BIN!\rtk.exe' -Force"
            del /f /q "!RTK_ZIP!" >nul 2>&1
            rmdir /s /q "!RTK_EXTRACT!" >nul 2>&1
            REM Add to PATH for this session
            set "PATH=!PATH!;!RTK_BIN!"
            echo i  RTK installed to !RTK_BIN!\rtk.exe
            echo ⚠  Ensure !RTK_BIN! is in your PATH permanently.
            echo    Add to PATH: setx PATH "%%PATH%%;!RTK_BIN!"
        ) else (
            echo ⚠  Download failed. Trying scoop...
            where scoop >nul 2>&1
            if !errorlevel!==0 (
                echo i  Installing RTK via scoop...
                scoop install rtk
            ) else (
                echo ⚠  Could not auto-install RTK.
                echo    Options:
                echo      1. Download manually: https://github.com/rtk-ai/rtk/releases/latest
                echo         Extract rtk.exe to a folder in your PATH.
                echo      2. Install scoop: https://scoop.sh then: scoop install rtk
                echo      3. Install cargo: https://rustup.rs then: cargo install rtk
            )
        )
        where rtk >nul 2>&1
        if !errorlevel!==0 (
            echo ✓  RTK installed successfully.
            call :prompt_rtk_init
        ) else (
            echo ⚠  RTK not on PATH. Restart terminal after adding !RTK_BIN! to PATH.
        )
    ) else (
        echo i  Skipping RTK.
    )
)

REM ===========================================================================
REM 3. Continue (VSCode Extension — manual only)
REM ===========================================================================
call :header "Continue (Local LLM Chat)"
if exist "%USERPROFILE%\.continue\config.yaml" (
    echo ✓  Continue config found.
) else (
    echo ⚠  Continue not configured.
    echo.
    echo   Continue is a VSCode extension for local LLM chat.
    echo   Install manually via VSCode Extensions panel.
    echo.
    echo   Setup guide: %SCRIPT_DIR%\continue-setup.md
    echo.
)

REM ===========================================================================
REM 4. Caveman Skill
REM ===========================================================================
call :header "Caveman Skill"
if exist "%USERPROFILE%\.agents\skills\caveman\SKILL.md" (
    echo ✓  Caveman skill already installed.
) else (
    echo ⚠  Caveman skill not found.
    set /p "CAV_INSTALL=?  Install Caveman? (response compression for Roo Code/Cline) [y/N] "
    if /i "!CAV_INSTALL!"=="y" (
        echo i  Installing Caveman via install.ps1...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = Join-Path $env:TEMP 'caveman-install.ps1'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1' -OutFile $t -UseBasicParsing; & $t; Remove-Item $t -Force -ErrorAction SilentlyContinue"
        if exist "%USERPROFILE%\.agents\skills\caveman\SKILL.md" (
            echo ✓  Caveman installed successfully.
        ) else (
            echo ⚠  Caveman install may have failed. Check output above.
            echo    Setup guide: %SCRIPT_DIR%\caveman-setup.md
        )
    ) else (
        echo i  Skipping Caveman.
    )
)

REM ===========================================================================
REM 5. Apply AI Rules (append mode)
REM ===========================================================================
call :header "AI Rules (Token Efficiency)"

if not exist "%RULES_SOURCE%" (
    echo ✗  Rules source not found: %RULES_SOURCE%
    goto :print_guidelines
)

set "PROJECT_DIR=%CD%"
echo i  Applying AI rules to: %PROJECT_DIR%
echo.

call :apply_rule ".clinerules"
call :apply_rule ".cursorrules"
call :apply_rule ".windsurfrules"
call :apply_rule "CLAUDE.md"
call :apply_rule "AGENTS.md"
call :apply_rule ".continuerules"
call :apply_rule ".github\copilot-instructions.md"

REM ===========================================================================
REM 6. Print Guidelines
REM ===========================================================================
:print_guidelines
call :header "Setup Complete — Guidelines"
echo   ┌─────────────────────────────────────────────────────────────────┐
echo   │                    USAGE GUIDELINES                              │
echo   ├─────────────────────────────────────────────────────────────────┤
echo   │                                                                 │
echo   │  1. Use Continue / local model for simple tasks and questions.  │
echo   │     - Zero token cost, runs on your local LLM server.           │
echo   │     - Best for: quick questions, brainstorming, snippets.       │
echo   │                                                                 │
echo   │  2. Keep Caveman + RTK enabled for all larger model sessions.   │
echo   │     - RTK compresses input tokens (command output).             │
echo   │     - Caveman compresses output tokens (responses).             │
echo   │     - Combined savings: often 80%+ reduction.                   │
echo   │                                                                 │
echo   │  3. GitHub Copilot Chat model selection: set to "auto".         │
echo   │     - Settings → Copilot → Chat → Model → auto                 │
echo   │     - Lets Copilot pick optimal model per task.                 │
echo   │                                                                 │
echo   │  4. Cline / Roo / Zoo Code:                                     │
echo   │     - TODO: Mode/model selection guide coming soon.             │
echo   │                                                                 │
echo   └─────────────────────────────────────────────────────────────────┘

goto :eof

REM ============================================================================
REM Subroutines
REM ============================================================================

:header
echo.
echo ═══ %~1 ═══
echo.
goto :eof

:prompt_codegraph_init
set /p "CG_INIT=?  Initialize CodeGraph in current project? [y/N] "
if /i "!CG_INIT!"=="y" (
    echo i  Running codegraph init...
    codegraph init 2>nul
    echo ✓  CodeGraph initialized.
)
goto :eof

:prompt_rtk_init
set /p "RTK_INIT=?  Initialize RTK for Cline/Roo Code (local + global)? [y/N] "
if /i "!RTK_INIT!"=="y" (
    echo i  Running rtk init --agent cline...
    rtk init --agent cline 2>nul
    echo i  Running rtk init -g...
    rtk init -g 2>nul
    echo ✓  RTK initialized.
)
goto :eof

:apply_rule
REM Append rules to target file, or create if not exists
set "TARGET_NAME=%~1"
set "TARGET=%PROJECT_DIR%\%TARGET_NAME%"

REM Create parent dir if needed
for %%I in ("%TARGET%") do set "TARGET_DIR=%%~dpI"
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

if exist "%TARGET%" (
    REM Check if rules already appended (by setup-coding-env) OR raw-copied (by setup-ai-rules)
    findstr /c:"Token Efficiency Rules (auto-appended by setup-coding-env" "%TARGET%" >nul 2>&1
    if !errorlevel!==0 (
        echo   - already has rules: %TARGET_NAME%
        goto :eof
    )
    findstr /c:"# Token Efficiency Rules" "%TARGET%" >nul 2>&1
    if !errorlevel!==0 (
        echo   - already has rules: %TARGET_NAME%
        goto :eof
    )
    REM Append separator and rules
    echo. >> "%TARGET%"
    (echo !SEPARATOR!) >> "%TARGET%"
    type "%RULES_SOURCE%" >> "%TARGET%"
    echo   ✓ appended: %TARGET_NAME%
) else (
    REM Create new file with rules
    copy /y "%RULES_SOURCE%" "%TARGET%" >nul
    echo   ✓ created:  %TARGET_NAME%
)
goto :eof

:show_help
echo Usage: %~nx0
echo.
echo Interactive setup script for token-optimized coding environment.
echo Checks/installs: CodeGraph, RTK, Continue, Caveman.
echo Then applies AI rules to all agent config files in the current project.
exit /b 0
