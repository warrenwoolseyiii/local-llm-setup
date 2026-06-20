# 🦴 Caveman Skill Setup

Caveman is an AI coding assistant skill that compresses LLM responses by ~75% while keeping full technical accuracy. It eliminates filler, articles, hedging, and pleasantries — delivering terse, precise answers.

- **Source:** [github.com/JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)
- **Type:** Roo Code / Cline skill (also works with other agents that support skills)

## 🛠️ Installation

Caveman is installed as a skill via the Roo Code / Cline skill system.

### **📁 Local (per-project)**

From your project root, use the skill installer to add from GitHub:

```
Install skill from: JuliusBrussee/caveman
```

This creates a `skills-lock.json` in your project and installs the skill files to `~/.agents/skills/caveman/`.

### **🌍 Global (all projects)**

Skills installed to `~/.agents/skills/` are available globally across all projects. The caveman skill bundle includes:

| Skill | Purpose |
|-------|---------|
| `caveman` | Core mode — terse responses |
| `cavecrew` | Multi-agent terse coordination |
| `caveman-commit` | Compressed commit messages |
| `caveman-compress` | Compress memory files (CLAUDE.md, todos) |
| `caveman-help` | Quick-reference card |
| `caveman-review` | Ultra-compressed code review comments |
| `caveman-stats` | Show token savings for current session |

---

## 🚀 Usage

### **Activating Caveman Mode**

Say any of these to your assistant:

- `"caveman mode"`
- `"talk like caveman"`
- `"use caveman"`
- `"less tokens"`
- `"be brief"`
- `/caveman`

### **Switching Intensity Levels**

```
/caveman lite     — No filler/hedging, keeps articles + full sentences
/caveman full     — Drop articles, fragments OK, short synonyms (default)
/caveman ultra    — Abbreviate prose words, arrows for causality, maximum terse
```

For Chinese (文言文) variants:

```
/caveman wenyan-lite
/caveman wenyan-full
/caveman wenyan-ultra
```

### **Deactivating**

```
"stop caveman"
"normal mode"
```

---

## 📖 Behavior Rules

- **Code blocks unchanged** — generated code, commits, and PRs always written normally
- **Auto-clarity escape** — drops terse style for:
  - Security warnings
  - Irreversible/destructive action confirmations
  - Multi-step sequences where compression causes ambiguity
- **Persistent** — stays active until explicitly stopped. No drift after many turns.
- **Language-aware** — matches user's dominant language (Portuguese user → Portuguese caveman)

---

## 📊 Example Comparison

**Normal:** "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by the authentication middleware checking token expiry with a less-than operator instead of less-than-or-equal."

**Caveman full:** "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

**Caveman ultra:** "Auth middleware: `<` → `<=` for token expiry."

---

## 🔧 Related Skills

| Command | What it does |
|---------|-------------|
| `/caveman-compress FILEPATH` | Compress a memory file (CLAUDE.md, etc.) to caveman format |
| `/caveman-help` | Show quick-reference card for all commands |
| `/caveman-stats` | Show real token savings for current session |
| `/caveman-review` | Ultra-compressed code review on a PR/diff |

---

## 💡 Pairs With RTK

Caveman compresses **output tokens** (assistant responses). RTK compresses **input tokens** (command output). Together they provide maximum token efficiency — often 80%+ total reduction.
