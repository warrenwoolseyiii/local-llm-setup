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

    $cg = Get-Command codegraph -ErrorAction SilentlyContinue
    if ($cg) {
        $ver = & codegraph --version 2>$null
        if (-not $ver) { $ver = "found" }
        Write-Ok "CodeGraph already installed: $ver"
        Initialize-CodeGraph
        return
    }

    Write-Warn "CodeGraph not found."
    if (Prompt-YN "Install CodeGraph? (codebase analysis tool)") {
        Write-Info "Installing CodeGraph..."
        # NOTE: CodeGraph install script is Unix-oriented.
        # On Windows, download binary manually or use alternative method.
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh" -OutFile "$env:TEMP\codegraph-install.sh"
            Write-Warn "CodeGraph installer is a shell script. Please install manually on Windows."
            Write-Warn "See: https://github.com/colbymchenry/codegraph for Windows instructions."
        } catch {
            Write-Err "Failed to download CodeGraph installer: $_"
        }
    } else {
        Write-Info "Skipping CodeGraph."
    }
}

function Initialize-CodeGraph {
    Write-Host ""
    if (Prompt-YN "Initialize CodeGraph in current project? (codegraph init)") {
        Write-Info "Running codegraph init..."
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
        # Prefer winget/scoop if available, fall back to curl script
        $scoop = Get-Command scoop -ErrorAction SilentlyContinue
        if ($scoop) {
            & scoop install rtk
        } else {
            try {
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh" -OutFile "$env:TEMP\rtk-install.sh"
                Write-Warn "RTK installer is a shell script. On Windows, try: scoop install rtk"
                Write-Warn "Or install via cargo: cargo install rtk"
                Write-Warn "See: https://github.com/rtk-ai/rtk for Windows instructions."
            } catch {
                Write-Err "Failed to download RTK installer: $_"
            }
        }

        $rtkCheck = Get-Command rtk -ErrorAction SilentlyContinue
        if ($rtkCheck) {
            Write-Ok "RTK installed successfully."
            Initialize-RTK
        } else {
            Write-Warn "RTK not on PATH. Install manually and ensure it's in PATH."
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
function Check-Continue {
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

    $skillPath = Join-Path $env:USERPROFILE ".agents\skills\caveman\SKILL.md"
    if (Test-Path $skillPath) {
        Write-Ok "Caveman skill already installed."
        return
    }

    Write-Warn "Caveman skill not found."
    if (Prompt-YN "Install Caveman? (response compression skill for Roo Code/Cline)") {
        Write-Host ""
        Write-Host "  Caveman must be installed through Roo Code / Cline UI:"
        Write-Host ""
        Write-Host "  1. Open Roo Code / Cline in VSCode"
        Write-Host "  2. Go to Skills settings"
        Write-Host "  3. Add skill from GitHub: JuliusBrussee/caveman"
        Write-Host ""
        Write-Host "  This installs to ~/.agents/skills/caveman/"
        Write-Host "  Setup guide: $ScriptDir\caveman-setup.md"
        Write-Host ""
        Write-Warn "Cannot auto-install — requires Roo Code UI."
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
            # Check if rules already appended
            $existingContent = Get-Content $target -Raw -ErrorAction SilentlyContinue
            if ($existingContent -and $existingContent.Contains("Token Efficiency Rules (auto-appended by setup-coding-env")) {
                Write-Host "  - already has rules: $targetName"
                continue
            }
            # Append to existing file
            Add-Content -Path $target -Value $Separator
            Add-Content -Path $target -Value $rulesContent
            Write-Host "  ✓ appended: $targetName"
        } else {
            # Create new file with rules
            Set-Content -Path $target -Value $rulesContent
            Write-Host "  ✓ created:  $targetName"
        }
    }
}

# ==============================================================================
# 6. Print Guidelines
# ==============================================================================
function Print-Guidelines {
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
Check-Continue
Install-Caveman
Apply-AIRules
Print-Guidelines
