# 🚀 Installing RTK (Rust Token Killer)

RTK is a CLI proxy that filters and compresses command output before it reaches your LLM context, saving 60–90% tokens on common operations.

- **Website:** [rtk-ai.app](https://www.rtk-ai.app/)
- **Source:** [github.com/rtk-ai/rtk](https://github.com/rtk-ai/rtk)

## 🛠️ Installation

### **💻 macOS (Homebrew — recommended)**

```bash
brew install rtk
```

### **💻 macOS / Linux (Shell installer)**

```bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
```

The installer places the binary in `~/.local/bin`. If that directory is not on your PATH, add it:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add the line above to `~/.zshrc` (Zsh) or `~/.bash_profile` (Bash) for persistence, then reload:

```bash
source ~/.zshrc   # or source ~/.bash_profile
```

### **💻 macOS / Linux (Cargo)**

Requires a Rust toolchain (`rustup`).

```bash
cargo install --git https://github.com/rtk-ai/rtk
```

### **🪟 Windows**

Download the latest release binary for your platform from [GitHub Releases](https://github.com/rtk-ai/rtk/releases) and place it on your PATH.

Alternatively, if you have a Rust toolchain installed:

```powershell
cargo install --git https://github.com/rtk-ai/rtk
```

### **✅ Verify Installation**

```bash
rtk --version
```

---

## 🌐 Initializing RTK

RTK injects rules into your AI coding assistant so it automatically prefixes shell commands with `rtk`. You can initialize it for a single project (local) or for all projects (global).

### **📁 Local (per-project)**

Run from within your project directory:

```bash
rtk init
```

This creates assistant-specific config files in the current project (e.g., `.clinerules` for Cline/Roo Code) that instruct the agent to use RTK.

#### Targeting a specific agent

```bash
rtk init --agent cline      # Cline / Roo Code (VS Code)
rtk init --agent claude      # Claude Code (default)
rtk init --agent cursor      # Cursor
rtk init --agent windsurf    # Windsurf (Cascade)
rtk init --agent copilot     # GitHub Copilot
```

### **🌍 Global (all projects)**

```bash
rtk init -g
```

This writes to your global assistant config directory so every project automatically uses RTK without per-repo setup.

```bash
rtk init -g --agent cline    # Global for Cline / Roo Code
```

### **👀 Preview changes (dry run)**

```bash
rtk init --dry-run           # Local preview
rtk init -g --dry-run        # Global preview
```

### **🗑️ Uninstall RTK config**

```bash
rtk init --uninstall         # Remove local config
rtk init -g --uninstall      # Remove global config
```

---

## 📊 Checking Token Savings

```bash
rtk gain                     # Summary of token savings
rtk gain --history           # Command history with savings
rtk discover                 # Find missed RTK opportunities
```
