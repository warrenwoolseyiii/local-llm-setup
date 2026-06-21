#!/usr/bin/env bash
#
# setup-ai-rules.sh — Apply unified AI rules (RTK + terse/caveman) to all coding agents.
#
# Usage:
#   ./setup-ai-rules.sh              # Apply to current project (local)
#   ./setup-ai-rules.sh --global     # Apply to global agent configs
#   ./setup-ai-rules.sh --uninstall  # Remove symlinks/copies from current project
#   ./setup-ai-rules.sh --global --uninstall  # Remove from global configs
#
# Supports: Claude Code, Cline/Roo Code, Cursor, Windsurf, GitHub Copilot, Codex, Continue
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/.ai-rules.md"

# Agent config filenames (relative to project root or global config dir)
LOCAL_TARGETS=(
  ".clinerules"
  ".cursorrules"
  ".windsurfrules"
  "CLAUDE.md"
  "AGENTS.md"
  ".continuerules"
  ".github/copilot-instructions.md"
)

# Global config directories per agent (agent:path pairs)
GLOBAL_AGENTS=("cline" "roo" "claude")
GLOBAL_PATHS=("$HOME/.cline/rules" "$HOME/.roo/rules" "$HOME/.claude/CLAUDE.md")

MODE="local"
UNINSTALL=false
FORCE_COPY=false

for arg in "$@"; do
  case "$arg" in
    --global) MODE="global" ;;
    --uninstall) UNINSTALL=true ;;
    --copy) FORCE_COPY=true ;;
    --help|-h)
      echo "Usage: $0 [--global] [--uninstall] [--copy]"
      echo ""
      echo "  (no flags)    Apply rules to current project directory (symlinks)"
      echo "  --copy        Copy instead of symlink (for committing to other repos)"
      echo "  --global      Apply rules to global agent config directories"
      echo "  --uninstall   Remove previously applied rules"
      exit 0
      ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# Check rules source exists
if [ ! -f "$RULES_SOURCE" ] && [ "$UNINSTALL" = false ]; then
  echo "ERROR: Rules source not found: $RULES_SOURCE"
  echo "Expected .ai-rules.md in same directory as this script."
  exit 1
fi

link_or_copy() {
  local target="$1"
  local target_dir
  target_dir="$(dirname "$target")"

  # Create parent dir if needed
  mkdir -p "$target_dir"

  # Remove existing file/symlink
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -f "$target"
  fi

  # Copy mode or symlink mode
  if [ "$FORCE_COPY" = true ]; then
    cp "$RULES_SOURCE" "$target"
    echo "  ✓ copied:    $target"
  elif ln -sf "$RULES_SOURCE" "$target" 2>/dev/null; then
    echo "  ✓ symlinked: $target → $RULES_SOURCE"
  else
    cp "$RULES_SOURCE" "$target"
    echo "  ✓ copied:    $target (symlink failed)"
  fi
}

remove_target() {
  local target="$1"
  if [ -L "$target" ]; then
    rm -f "$target"
    echo "  ✗ removed symlink: $target"
  elif [ -f "$target" ]; then
    # Only remove if content matches our rules (safety check)
    if diff -q "$RULES_SOURCE" "$target" >/dev/null 2>&1; then
      rm -f "$target"
      echo "  ✗ removed copy: $target"
    else
      echo "  ⚠ skipped (modified): $target"
    fi
  else
    echo "  - not present: $target"
  fi
}

echo ""
if [ "$MODE" = "local" ]; then
  PROJECT_DIR="$(pwd)"
  echo "Project: $PROJECT_DIR"
  echo "Source:  $RULES_SOURCE"
  echo ""

  if [ "$UNINSTALL" = true ]; then
    echo "Removing AI rules from project..."
    for target in "${LOCAL_TARGETS[@]}"; do
      remove_target "$PROJECT_DIR/$target"
    done
  else
    echo "Applying AI rules to project..."
    for target in "${LOCAL_TARGETS[@]}"; do
      link_or_copy "$PROJECT_DIR/$target"
    done
  fi

elif [ "$MODE" = "global" ]; then
  echo "Applying AI rules globally..."
  echo "Source: $RULES_SOURCE"
  echo ""

  if [ "$UNINSTALL" = true ]; then
    echo "Removing global AI rules..."
    for i in "${!GLOBAL_AGENTS[@]}"; do
      agent="${GLOBAL_AGENTS[$i]}"
      target="${GLOBAL_PATHS[$i]}"
      echo "  [$agent]"
      remove_target "$target"
    done
  else
    for i in "${!GLOBAL_AGENTS[@]}"; do
      agent="${GLOBAL_AGENTS[$i]}"
      target="${GLOBAL_PATHS[$i]}"
      echo "  [$agent]"
      link_or_copy "$target"
    done
  fi
fi

echo ""
echo "Done."
