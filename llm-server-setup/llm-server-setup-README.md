# LLM Server Setup Script

Automated setup script for converting gaming laptops into headless LLM inference servers running Ubuntu Server 24.04 LTS.

## Prerequisites

- Fresh install of **Ubuntu Server 24.04 LTS**
- NVIDIA GPU (RTX 3060–4070 range)
- Internet connection
- SSH access (or physical keyboard/monitor)

## Quick Start

```bash
# 1. Copy the scripts to your server
scp -r scripts/llm-server-setup/ user@server:~/

# 2. SSH into the server
ssh user@server

# 3. Edit the config file
nano ~/llm-server-setup/llm-server.conf

# 4. Run the full setup
sudo ~/llm-server-setup/llm-server-setup.sh --all
```

> **Note:** The NVIDIA driver phase will prompt for a reboot. After rebooting, re-run
> `sudo ./llm-server-setup.sh --all` — it will skip completed phases automatically.

## Files

| File | Description |
|------|-------------|
| `llm-server-setup.sh` | Main setup script (run with `sudo`) |
| `llm-server.conf` | Configuration file — edit before running |
| `llm-server-setup-README.md` | This file |

## Configuration

Edit `llm-server.conf` before running. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `HOSTNAME` | `llm-server` | Machine hostname (used by Tailscale MagicDNS) |
| `OLLAMA_HOST` | `0.0.0.0` | Interface Ollama listens on |
| `OLLAMA_MODELS` | `interactive` | Models to pull (`interactive` = choose at runtime) |
| `INSTALL_OPEN_WEBUI` | `yes` | Deploy Open WebUI (ChatGPT-like web interface) |
| `INSTALL_TAILSCALE` | `yes` | Install Tailscale VPN for remote access |
| `NVIDIA_DRIVER` | `auto` | `auto` or a specific version like `560` |
| `SSH_KEY_ONLY` | `no` | Disable password SSH (set up keys first!) |

## Usage

### Run everything
```bash
sudo ./llm-server-setup.sh --all
```

### Run specific phases
```bash
# Just system setup and NVIDIA drivers
sudo ./llm-server-setup.sh --phase system --phase nvidia

# Just Ollama (after drivers are installed and rebooted)
sudo ./llm-server-setup.sh --phase ollama

# Just security hardening
sudo ./llm-server-setup.sh --phase security
```

### Check progress
```bash
sudo ./llm-server-setup.sh --status
```

### Reset progress (re-run everything)
```bash
sudo ./llm-server-setup.sh --reset
sudo ./llm-server-setup.sh --all
```

### Use a custom config file
```bash
sudo ./llm-server-setup.sh --all --config /path/to/my-config.conf
```

## Phases

The script runs in 7 phases, executed in order:

| # | Phase | What It Does |
|---|-------|--------------|
| 1 | `system` | Updates OS, installs packages, sets hostname, configures lid close, disables bloat services |
| 2 | `nvidia` | Installs NVIDIA GPU drivers (prompts for reboot) |
| 3 | `ollama` | Installs Ollama, configures network listening, pulls LLM models |
| 4 | `docker` | Installs Docker Engine |
| 5 | `webui` | Deploys Open WebUI container |
| 6 | `tailscale` | Installs and authenticates Tailscale VPN |
| 7 | `security` | Configures UFW firewall, fail2ban, SSH hardening |

Each phase is **idempotent** — it checks if it has already been completed and skips if so. Progress is tracked in `/var/tmp/llm-server-setup-progress`.

## Two-Laptop Setup

To set up both laptops:

### Laptop 1 (ROG Zephyrus — Chat Server)
```bash
# Edit config
HOSTNAME="rog-zephyrus"
OLLAMA_MODELS="llama3.1:8b"

# Run
sudo ./llm-server-setup.sh --all
```

### Laptop 2 (MSI Gaming — Code Server)
```bash
# Edit config
HOSTNAME="msi-gaming"
OLLAMA_MODELS="deepseek-coder-v2:16b"

# Run
sudo ./llm-server-setup.sh --all
```

### Connect Open WebUI to Both

On whichever laptop runs Open WebUI, set:
```
OPEN_WEBUI_OLLAMA_URLS="http://localhost:11434;http://<other-laptop-tailscale-ip>:11434"
```

## After Setup

### Verify everything works
```bash
# GPU status
nvidia-smi

# Ollama models
ollama list

# Chat in terminal
ollama run llama3.1:8b

# Test API
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"Hello!"}]}'

# Tailscale status
tailscale status

# Open WebUI
# Visit http://localhost:3000 in a browser
```

### VS Code Integration

Install the **Continue** extension in VS Code and configure `~/.continue/config.json`:

```json
{
  "models": [
    {
      "title": "Chat (Llama 3.1)",
      "provider": "ollama",
      "model": "llama3.1:8b",
      "apiBase": "http://rog-zephyrus:11434"
    },
    {
      "title": "Code (DeepSeek)",
      "provider": "ollama",
      "model": "deepseek-coder-v2:16b",
      "apiBase": "http://msi-gaming:11434"
    }
  ]
}
```

Replace hostnames with your Tailscale IPs if MagicDNS is not enabled.

## Logs & Troubleshooting

| Item | Location |
|------|----------|
| Setup log | `/var/log/llm-server-setup.log` |
| Progress tracker | `/var/tmp/llm-server-setup-progress` |
| Ollama logs | `journalctl -u ollama` |
| Open WebUI logs | `docker logs open-webui` |
| Tailscale logs | `journalctl -u tailscaled` |

### Common Issues

**NVIDIA driver fails to install:**
- Ensure Secure Boot is disabled in BIOS
- Try a specific driver version: `NVIDIA_DRIVER="560"` in config

**Ollama can't access GPU after reboot:**
- Check `nvidia-smi` works first
- Restart Ollama: `sudo systemctl restart ollama`

**Can't connect remotely:**
- Verify Tailscale is connected: `tailscale status`
- Check UFW isn't blocking: `sudo ufw status`
- Verify Ollama is listening: `ss -tlnp | grep 11434`

**Open WebUI can't reach Ollama:**
- Ensure `--add-host=host.docker.internal:host-gateway` was used
- Check Ollama is running: `curl http://localhost:11434/api/tags`
