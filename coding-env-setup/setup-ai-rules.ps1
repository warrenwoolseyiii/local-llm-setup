#
# setup-ai-rules.ps1 — Apply unified AI rules (RTK + terse/caveman) to all coding agents.
#
# Usage:
#   .\setup-ai-rules.ps1              # Apply to current project (local)
#   .\setup-ai-rules.ps1 -Global      # Apply to global agent configs
#   .\setup-ai-rules.ps1 -Uninstall   # Remove copies from current project
#   .\setup-ai-rules.ps1 -Global -Uninstall  # Remove from global configs
#
# Supports: Claude Code, Cline/Roo Code, Cursor, Windsurf, GitHub Copilot, Codex, Continue
#

param(
    [switch]$Global,
    [switch]$Uninstall,
    [switch]$Copy,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RulesSource = Join-Path $ScriptDir ".ai-rules.md"

# Agent config filenames (relative to project root or global config dir)
$LocalTargets = @(
    ".clinerules",
    ".cursorrules",
    ".windsurfrules",
    "CLAUDE.md",
    "AGENTS.md",
    ".continuerules",
    ".github\copilot-instructions.md"
)

# Global config directories per agent
$GlobalAgents = @("cline", "roo", "claude")
$GlobalPaths = @(
    (Join-Path $env:USERPROFILE ".cline\rules"),
    (Join-Path $env:USERPROFILE ".roo\rules"),
    (Join-Path $env:USERPROFILE ".claude\CLAUDE.md")
)

if ($Help) {
    Write-Host "Usage: .\setup-ai-rules.ps1 [-Global] [-Uninstall] [-Copy]"
    Write-Host ""
    Write-Host "  (no flags)    Apply rules to current project directory (copy)"
    Write-Host "  -Copy         Explicit copy mode (default on Windows, symlinks require admin)"
    Write-Host "  -Global       Apply rules to global agent config directories"
    Write-Host "  -Uninstall    Remove previously applied rules"
    exit 0
}

# Check rules source exists
if (-not (Test-Path $RulesSource) -and -not $Uninstall) {
    Write-Host "ERROR: Rules source not found: $RulesSource"
    Write-Host "Expected .ai-rules.md in same directory as this script."
    exit 1
}

function Copy-OrLink {
    param([string]$Target)

    $TargetDir = Split-Path -Parent $Target

    # Create parent dir if needed
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    # Remove existing file
    if (Test-Path $Target) {
        Remove-Item -Path $Target -Force
    }

    # NOTE: Windows symlinks require admin privileges, so default to copy.
    # Use -Copy flag explicitly or it copies by default.
    if ($Copy -or (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Copy-Item -Path $RulesSource -Destination $Target -Force
        Write-Host "  ✓ copied:    $Target"
    } else {
        try {
            New-Item -ItemType SymbolicLink -Path $Target -Target $RulesSource -Force | Out-Null
            Write-Host "  ✓ symlinked: $Target → $RulesSource"
        } catch {
            Copy-Item -Path $RulesSource -Destination $Target -Force
            Write-Host "  ✓ copied:    $Target (symlink failed)"
        }
    }
}

function Remove-Target {
    param([string]$Target)

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        # Check if symlink
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Remove-Item -Path $Target -Force
            Write-Host "  ✗ removed symlink: $Target"
        } else {
            # Only remove if content matches our rules (safety check)
            $sourceContent = if (Test-Path $RulesSource) { Get-Content $RulesSource -Raw -ErrorAction SilentlyContinue } else { $null }
            $targetContent = Get-Content $Target -Raw -ErrorAction SilentlyContinue
            if ($null -eq $sourceContent -or $sourceContent -eq $targetContent) {
                Remove-Item -Path $Target -Force
                Write-Host "  ✗ removed copy: $Target"
            } else {
                Write-Host "  ⚠ skipped (modified): $Target"
            }
        }
    } else {
        Write-Host "  - not present: $Target"
    }
}

Write-Host ""

if (-not $Global) {
    # Local mode
    $ProjectDir = Get-Location

    Write-Host "Project: $ProjectDir"
    Write-Host "Source:  $RulesSource"
    Write-Host ""

    if ($Uninstall) {
        Write-Host "Removing AI rules from project..."
        foreach ($target in $LocalTargets) {
            Remove-Target (Join-Path $ProjectDir $target)
        }
    } else {
        Write-Host "Applying AI rules to project..."
        foreach ($target in $LocalTargets) {
            Copy-OrLink (Join-Path $ProjectDir $target)
        }
    }
} else {
    # Global mode
    Write-Host "Applying AI rules globally..."
    Write-Host "Source: $RulesSource"
    Write-Host ""

    if ($Uninstall) {
        Write-Host "Removing global AI rules..."
        for ($i = 0; $i -lt $GlobalAgents.Count; $i++) {
            $agent = $GlobalAgents[$i]
            $target = $GlobalPaths[$i]
            Write-Host "  [$agent]"
            Remove-Target $target
        }
    } else {
        for ($i = 0; $i -lt $GlobalAgents.Count; $i++) {
            $agent = $GlobalAgents[$i]
            $target = $GlobalPaths[$i]
            Write-Host "  [$agent]"
            Copy-OrLink $target
        }
    }
}

Write-Host ""
Write-Host "Done."
