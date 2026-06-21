#!/usr/bin/env bash
#
# setup-coding-env.sh — Master setup script for token-optimized coding environment.
#
# Checks for and optionally installs: CodeGraph, RTK, Caveman, Continue.
# Applies AI rules (RTK + caveman/terse) to all agent config files.
#
# Usage:
#   ./setup-coding-env.sh           # Interactive setup
#   ./setup-coding-env.sh --help    # Show help
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/.ai-rules.md"
SEPARATOR="
# --- Token Efficiency Rules (auto-appended by setup-coding-env.sh) ---
"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✓${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
err()   { echo -e "${RED}✗${NC}  $1"; }
header(){ echo -e "\n${BOLD}═══ $1 ═══${NC}\n"; }

prompt_yn() {
  local msg="$1"
  local response
  echo -en "${YELLOW}?${NC}  $msg [y/N] "
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 1. CodeGraph
# ═══════════════════════════════════════════════════════════════════════
install_codegraph() {
  header "CodeGraph"

  if command -v codegraph &>/dev/null; then
    ok "CodeGraph already installed: $(codegraph --version 2>/dev/null || echo 'found')"
    return
  fi

  warn "CodeGraph not found."
  if prompt_yn "Install CodeGraph? (codebase analysis tool)"; then
    info "Installing CodeGraph..."
    curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
    echo ""
    if command -v codegraph &>/dev/null; then
      ok "CodeGraph installed successfully."
    else
      warn "CodeGraph installed but not on PATH. Add ~/.local/bin to PATH."
    fi
  else
    info "Skipping CodeGraph."
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# 2. RTK
# ═══════════════════════════════════════════════════════════════════════
install_rtk() {
  header "RTK (Rust Token Killer)"

  if command -v rtk &>/dev/null; then
    ok "RTK already installed: $(rtk --version 2>/dev/null)"
    # Still offer to init if not already done
    init_rtk
    return
  fi

  warn "RTK not found."
  if prompt_yn "Install RTK? (CLI proxy for token savings)"; then
    info "Installing RTK..."
    # Prefer brew on macOS
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew &>/dev/null; then
      brew install rtk
    else
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    fi
    echo ""
    if command -v rtk &>/dev/null; then
      ok "RTK installed successfully."
      init_rtk
    else
      warn "RTK installed but not on PATH. Add ~/.local/bin to PATH."
      warn "After fixing PATH, run: rtk init --agent cline && rtk init -g"
    fi
  else
    info "Skipping RTK."
  fi
}

init_rtk() {
  echo ""
  if prompt_yn "Initialize RTK for Cline/Roo Code (local + global)?"; then
    info "Running rtk init --agent cline (local)..."
    rtk init --agent cline 2>/dev/null || true
    info "Running rtk init -g (global)..."
    rtk init -g 2>/dev/null || true
    ok "RTK initialized."
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# 3. Continue (VSCode Extension — manual only)
# ═══════════════════════════════════════════════════════════════════════
check_continue() {
  header "Continue (Local LLM Chat)"

  if [ -f "$HOME/.continue/config.yaml" ]; then
    ok "Continue config found (~/.continue/config.yaml)."
  else
    warn "Continue not configured."
    echo ""
    echo "  Continue is a VSCode extension for local LLM chat."
    echo "  Install manually via VSCode Extensions panel."
    echo ""
    echo "  Setup guide: $SCRIPT_DIR/continue-setup.md"
    echo ""
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# 4. Caveman Skill
# ═══════════════════════════════════════════════════════════════════════
install_caveman() {
  header "Caveman Skill"

  if [ -f "$HOME/.agents/skills/caveman/SKILL.md" ]; then
    ok "Caveman skill already installed."
    return
  fi

  warn "Caveman skill not found."
  if prompt_yn "Install Caveman? (response compression skill for Roo Code/Cline)"; then
    echo ""
    echo "  Caveman must be installed through Roo Code / Cline UI:"
    echo ""
    echo "  1. Open Roo Code / Cline in VSCode"
    echo "  2. Go to Skills settings"
    echo "  3. Add skill from GitHub: ${BOLD}JuliusBrussee/caveman${NC}"
    echo ""
    echo "  This installs to ~/.agents/skills/caveman/"
    echo "  Setup guide: $SCRIPT_DIR/caveman-setup.md"
    echo ""
    warn "Cannot auto-install — requires Roo Code UI."
  else
    info "Skipping Caveman."
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# 5. Apply AI Rules (append mode)
# ═══════════════════════════════════════════════════════════════════════
apply_ai_rules() {
  header "AI Rules (Token Efficiency)"

  if [ ! -f "$RULES_SOURCE" ]; then
    err "Rules source not found: $RULES_SOURCE"
    return
  fi

  local project_dir
  project_dir="$(pwd)"

  local targets=(
    ".clinerules"
    ".cursorrules"
    ".windsurfrules"
    "CLAUDE.md"
    "AGENTS.md"
    ".continuerules"
    ".github/copilot-instructions.md"
  )

  info "Applying AI rules to: $project_dir"
  echo ""

  for target_name in "${targets[@]}"; do
    local target="$project_dir/$target_name"
    local target_dir
    target_dir="$(dirname "$target")"

    # Create parent dir if needed
    mkdir -p "$target_dir"

    if [ -f "$target" ] || [ -L "$target" ]; then
      # Check if rules already appended
      if grep -qF "Token Efficiency Rules (auto-appended by setup-coding-env.sh)" "$target" 2>/dev/null; then
        echo "  - already has rules: $target_name"
        continue
      fi
      # Append to existing file
      echo "$SEPARATOR" >> "$target"
      cat "$RULES_SOURCE" >> "$target"
      echo "  ✓ appended: $target_name"
    else
      # Create new file with rules
      cat "$RULES_SOURCE" > "$target"
      echo "  ✓ created:  $target_name"
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════════
# 6. Print Guidelines
# ═══════════════════════════════════════════════════════════════════════
print_guidelines() {
  header "Setup Complete — Guidelines"

  cat <<'EOF'
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
EOF
}

# ═══════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: $0"
  echo ""
  echo "Interactive setup script for token-optimized coding environment."
  echo "Checks/installs: CodeGraph, RTK, Continue, Caveman."
  echo "Then applies AI rules to all agent config files in the current project."
  exit 0
fi

echo -e "${BOLD}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        Token-Optimized Coding Environment Setup              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

install_codegraph
install_rtk
check_continue
install_caveman
apply_ai_rules
print_guidelines
