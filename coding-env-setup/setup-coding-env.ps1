#
# setup-coding-env.ps1 — Master setup script for token-optimized coding environment.
#
# Checks for and optionally installs: CodeGraph, RTK, Caveman, Continue.
# Applies AI rules (RTK + caveman/terse) to all agent config files.
#
# Usage:
#   .\setup-coding-env.ps1           # Interactive setup
#   .\setup-coding-env.ps1 -Help     # Show help
#

param(
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RulesSource = Join-Path $ScriptDir ".ai-rules.md"
$Separator = "`n# --- Token Efficiency Rules (auto-appended by setup-coding-env.ps1) ---`n"

# --- Colors (PowerShell supports ANSI on Windows 10+) ------------------------
function Write-Info  { param([string]$Msg) Write-Host "i  $Msg" -ForegroundColor Blue }
function Write-Ok    { param([string]$Msg) Write-Host "✓  $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "⚠  $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "✗  $Msg" -ForegroundColor Red }
function Write-Header { param([string]$Msg) Write-Host "`n═══ $Msg ═══`n" -ForegroundColor White }

function Prompt-YN {
    param([string]$Msg)
    $response = Read-Host "?  $Msg [y/N]"
    return ($response -match '^[Yy]$')
}

# ==============================================================================
# 1. CodeGraph
# ==============================================================================
function Install-CodeGraph {
    Write-Header "CodeGraph"

    # Check if the codegraph command is found, and if so, initialize CodeGraph
    $codegraph = Get-Command codegraph -ErrorAction SilentlyContinue
    if ($codegraph) {
        Write-Ok "CodeGraph command found."
        Initialize-CodeGraph
        return
    }

    Write-Warn "CodeGraph not found."
    if (Prompt-YN "Install CodeGraph? (codebase analysis tool)") {
        Write-Info "Installing CodeGraph..."
        $installDir = Join-Path $env:USERPROFILE ".local\bin"
        if (-not (Test-Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        }
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1" -OutFile "codegraph-install.ps1"
            & .\codegraph-install.ps1 -InstallDir $installDir
            Remove-Item "codegraph-install.ps1" -Force -ErrorAction SilentlyContinue
            # Ensure install dir is on PATH for this session
            if ($env:PATH -notlike "*$installDir*") {
                $env:PATH = "$installDir;$env:PATH"
            }
            Initialize-CodeGraph
        } catch {
            Write-Warn "See: https://github.com/colbymchenry/codegraph for Windows instructions."
            Write-Err "Failed to install CodeGraph: $_"
        }
    } else {
        Write-Info "Skipping CodeGraph."
    }
}

function Initialize-CodeGraph {
    # First check to see if .codegraph directory exists in the current project, if it does, print success and skip init
    $codegraphDir = Join-Path (Get-Location) ".codegraph"
    if (Test-Path $codegraphDir) {
        Write-Ok "CodeGraph directory already exists in the current project."
        return
    }
    Write-Host ""
    if (Prompt-YN "Initialize CodeGraph in current project? (codegraph init)") {
        Write-Info "Running codegraph init in $(Get-Location)..."
        try { & codegraph init 2>$null } catch { }
        Write-Ok "CodeGraph initialized."
    }
}

# ==============================================================================
# 2. RTK
# ==============================================================================
function Install-RTK {
    Write-Header "RTK (Rust Token Killer)"

    $rtk = Get-Command rtk -ErrorAction SilentlyContinue
    if ($rtk) {
        $ver = & rtk --version 2>$null
        Write-Ok "RTK already installed: $ver"
        Initialize-RTK
        return
    }

    Write-Warn "RTK not found."
    if (Prompt-YN "Install RTK? (CLI proxy for token savings)") {
        Write-Info "Installing RTK..."

        $rtkZip    = Join-Path $env:TEMP "rtk-windows.zip"
        $rtkExtract = Join-Path $env:TEMP "rtk-extract"
        $rtkBin    = Join-Path $env:USERPROFILE ".local\bin"
        $rtkExe    = Join-Path $rtkBin "rtk.exe"
        $releaseUrl = "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-x86_64-pc-windows-msvc.zip"

        $installed = $false

        # 1. Try direct zip download from GitHub releases
        try {
            Write-Info "Downloading RTK from GitHub releases..."
            Invoke-WebRequest -Uri $releaseUrl -OutFile $rtkZip -UseBasicParsing
            if (-not (Test-Path $rtkBin)) { New-Item -ItemType Directory -Path $rtkBin -Force | Out-Null }
            Expand-Archive -Path $rtkZip -DestinationPath $rtkExtract -Force
            Copy-Item (Join-Path $rtkExtract "rtk.exe") $rtkExe -Force
            Remove-Item $rtkZip -Force -ErrorAction SilentlyContinue
            Remove-Item $rtkExtract -Recurse -Force -ErrorAction SilentlyContinue
            # Add to PATH for this session
            $env:PATH = "$rtkBin;$env:PATH"
            Write-Ok "RTK extracted to $rtkExe"
            Write-Warn "Add to permanent PATH: [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$rtkBin', 'User')"
            $installed = $true
        } catch {
            Write-Warn "Direct download failed: $_"
            # 2. Fall back to scoop
            $scoop = Get-Command scoop -ErrorAction SilentlyContinue
            if ($scoop) {
                Write-Info "Trying scoop install rtk..."
                try {
                    & scoop install rtk
                    $installed = $true
                } catch {
                    Write-Warn "scoop install failed: $_"
                }
            }
        }

        if (-not $installed) {
            Write-Warn "Could not auto-install RTK. Options:"
            Write-Host "  1. Download manually: https://github.com/rtk-ai/rtk/releases/latest"
            Write-Host "     Extract rtk.exe to a folder in your PATH."
            Write-Host "  2. Install scoop: https://scoop.sh  then: scoop install rtk"
            Write-Host "  3. Install cargo: https://rustup.rs  then: cargo install rtk"
        }

        $rtkCheck = Get-Command rtk -ErrorAction SilentlyContinue
        if ($rtkCheck) {
            Write-Ok "RTK installed successfully."
            Initialize-RTK
        } else {
            Write-Warn "RTK not found on PATH yet. Restart terminal after adding $rtkBin to PATH."
            Write-Warn "After fixing PATH, run: rtk init --agent cline; rtk init -g"
        }
    } else {
        Write-Info "Skipping RTK."
    }
}

function Initialize-RTK {
    Write-Host ""
    if (Prompt-YN "Initialize RTK for Cline/Roo Code (local + global)?") {
        Write-Info "Running rtk init --agent cline (local)..."
        try { & rtk init --agent cline 2>$null } catch { }
        Write-Info "Running rtk init -g (global)..."
        try { & rtk init -g 2>$null } catch { }
        Write-Ok "RTK initialized."
    }
}

# ==============================================================================
# 3. Continue (VSCode Extension — manual only)
# ==============================================================================
function Show-ContinueStatus {
    Write-Header "Continue (Local LLM Chat)"

    $configPath = Join-Path $env:USERPROFILE ".continue\config.yaml"
    if (Test-Path $configPath) {
        Write-Ok "Continue config found ($configPath)."
    } else {
        Write-Warn "Continue not configured."
        Write-Host ""
        Write-Host "  Continue is a VSCode extension for local LLM chat."
        Write-Host "  Install manually via VSCode Extensions panel."
        Write-Host ""
        Write-Host "  Setup guide: $ScriptDir\continue-setup.md"
        Write-Host ""
    }
}

# ==============================================================================
# 4. Caveman Skill
# ==============================================================================
function Install-Caveman {
    Write-Header "Caveman Skill"

    # All skills would be installed in the directory the user is calling this script from
    $currentDir = Get-Location
    $skillPath = Join-Path $currentDir ".agents\skills\caveman\SKILL.md"
    if (Test-Path $skillPath) {
        Write-Ok "Caveman skill already installed."
        return
    }

    Write-Warn "Caveman skill not found."
    if (Prompt-YN "Install Caveman? (response compression skill for Roo Code/Cline)") {
        Write-Info "Installing Caveman via install.ps1..."
        $caveTmp = Join-Path $env:TEMP "caveman-install.ps1"
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1" -OutFile $caveTmp -UseBasicParsing
            & $caveTmp
            Remove-Item $caveTmp -Force -ErrorAction SilentlyContinue
            Write-Ok "Caveman installed successfully."
        } catch {
            Remove-Item $caveTmp -Force -ErrorAction SilentlyContinue
            Write-Err "Caveman install failed: $_"
            Write-Host "  Setup guide: $ScriptDir\caveman-setup.md"
        }
    } else {
        Write-Info "Skipping Caveman."
    }
}

# ==============================================================================
# 5. Apply AI Rules (append mode)
# ==============================================================================
function Apply-AIRules {
    Write-Header "AI Rules (Token Efficiency)"

    if (-not (Test-Path $RulesSource)) {
        Write-Err "Rules source not found: $RulesSource"
        return
    }

    $ProjectDir = Get-Location

    $targets = @(
        ".clinerules",
        ".cursorrules",
        ".windsurfrules",
        "CLAUDE.md",
        "AGENTS.md",
        ".continuerules",
        ".github\copilot-instructions.md"
    )

    Write-Info "Applying AI rules to: $ProjectDir"
    Write-Host ""

    $rulesContent = Get-Content $RulesSource -Raw

    foreach ($targetName in $targets) {
        $target = Join-Path $ProjectDir $targetName
        $targetDir = Split-Path -Parent $target

        # Create parent dir if needed
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        if (Test-Path $target) {
            # Check if rules already appended (by setup-coding-env) OR raw-copied (by setup-ai-rules)
            $existingContent = Get-Content $target -Raw -ErrorAction SilentlyContinue
            if ($existingContent -and ($existingContent.Contains("Token Efficiency Rules (auto-appended by setup-coding-env") -or $existingContent.Contains("# Token Efficiency Rules"))) {
                Write-Host "  - already has rules: $targetName"
                continue
            }
            # Append to existing file
            Add-Content -Path $target -Value $Separator -Encoding UTF8
            Add-Content -Path $target -Value $rulesContent -Encoding UTF8
            Write-Host "  ✓ appended: $targetName"
        } else {
            # Create new file with rules
            Set-Content -Path $target -Value $rulesContent -Encoding UTF8
            Write-Host "  ✓ created:  $targetName"
        }
    }
}

# ==============================================================================
# 6. Print Guidelines
# ==============================================================================
function Show-Guidelines {
    Write-Header "Setup Complete — Guidelines"

    Write-Host @"
  ┌─────────────────────────────────────────────────────────────────┐
  │                    USAGE GUIDELINES                              │
  ├─────────────────────────────────────────────────────────────────┤
  │                                                                 │
  │  1. Use Continue / local model for simple tasks and questions.  │
  │     - Zero token cost, runs on your local LLM server.           │
  │     - Best for: quick questions, brainstorming, snippets.       │
  │                                                                 │
  │  2. Keep Caveman + RTK enabled for all larger model sessions.   │
  │     - RTK compresses input tokens (command output).             │
  │     - Caveman compresses output tokens (responses).             │
  │     - Combined savings: often 80%+ reduction.                   │
  │                                                                 │
  │  3. GitHub Copilot Chat model selection: set to "auto".         │
  │     - Settings → Copilot → Chat → Model → auto                 │
  │     - Lets Copilot pick optimal model per task.                 │
  │                                                                 │
  │  4. Cline / Roo / Zoo Code:                                     │
  │     - TODO: Mode/model selection guide coming soon.             │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
"@
}

# ==============================================================================
# Main
# ==============================================================================

if ($Help) {
    Write-Host "Usage: .\setup-coding-env.ps1"
    Write-Host ""
    Write-Host "Interactive setup script for token-optimized coding environment."
    Write-Host "Checks/installs: CodeGraph, RTK, Continue, Caveman."
    Write-Host "Then applies AI rules to all agent config files in the current project."
    exit 0
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor White
Write-Host "║        Token-Optimized Coding Environment Setup              ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""

Install-CodeGraph
Install-RTK
Show-ContinueStatus
Install-Caveman
Apply-AIRules
Show-Guidelines
