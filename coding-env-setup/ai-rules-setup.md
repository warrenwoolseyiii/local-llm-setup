# 🤖 AI Rules Setup

Universal token-efficiency rules applied to all AI coding agents via a single source file.

## What It Does

Applies [`.ai-rules.md`](./coding-env-setup/.ai-rules.md) (RTK + terse response rules) to all supported agents:

| Agent | Config file created |
|-------|-------------------|
| Claude Code | `CLAUDE.md` |
| Cline / Roo Code | `.clinerules` |
| Cursor | `.cursorrules` |
| Windsurf | `.windsurfrules` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Codex | `AGENTS.md` |
| Continue | `.continuerules` |

## Usage

### Apply to a project (symlinks)

```bash
cd /path/to/your/project
/path/to/local-llm-setup/coding-env-setup/setup-ai-rules.sh
```

### Apply to a project (copies — for committing to repo)

```bash
cd /path/to/your/project
/path/to/local-llm-setup/coding-env-setup/setup-ai-rules.sh --copy
```

### Apply globally

```bash
./coding-env-setup/setup-ai-rules.sh --global
```

### Remove from a project

```bash
cd /path/to/your/project
/path/to/local-llm-setup/coding-env-setup/setup-ai-rules.sh --uninstall
```

### Remove global config

```bash
./coding-env-setup/setup-ai-rules.sh --global --uninstall
```

## Customization

Edit [`coding-env-setup/.ai-rules.md`](./coding-env-setup/.ai-rules.md) — all symlinked projects pick up changes instantly. Copied projects need re-run with `--copy`.

## How It Pairs With Caveman

`.ai-rules.md` embeds terse response rules directly (works for all agents). For Cline/Roo Code, the full caveman skill provides additional features (intensity levels, auto-clarity, etc.) via the skills system. The embedded rules serve as a baseline for agents that don't support skills.
