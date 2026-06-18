#!/usr/bin/env bash
# =============================================================================
# LLM Server Setup Script
# =============================================================================
# Automated setup for a local LLM inference server on Ubuntu Server 24.04 LTS.
# Designed for gaming laptops repurposed as headless LLM servers.
#
# Usage:
#   sudo ./llm-server-setup.sh [--all | --phase <phase> ...] [--config <path>]
#
# Phases: system, nvidia, ollama, docker, webui, tailscale, security
#
# See llm-server-setup-README.md for full documentation.
# =============================================================================

set -euo pipefail

# --- Constants ---------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/llm-server.conf"
LOG_FILE="/var/log/llm-server-setup.log"
PROGRESS_FILE="/var/tmp/llm-server-setup-progress"

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Logging -----------------------------------------------------------------
log() { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
err() { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE" >&2; }
info() { echo -e "${BLUE}[i]${NC} $*" | tee -a "$LOG_FILE"; }
header() {
    echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}  $*${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}\n" | tee -a "$LOG_FILE"
}

# --- Prerequisites -----------------------------------------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root (use sudo)."
        exit 1
    fi
}

check_ubuntu() {
    if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        warn "This script is designed for Ubuntu. Proceeding anyway, but things may break."
    fi
}

# --- Config Loading ----------------------------------------------------------
load_config() {
    local config_path="$1"
    if [[ ! -f "$config_path" ]]; then
        err "Config file not found: $config_path"
        err "Copy llm-server.conf.example to llm-server.conf and edit it first."
        exit 1
    fi
    info "Loading config from: $config_path"
    # shellcheck source=llm-server.conf
    source "$config_path"
}

# --- Progress Tracking -------------------------------------------------------
mark_phase_done() {
    echo "$1" >> "$PROGRESS_FILE"
    log "Phase '$1' completed and recorded."
}

is_phase_done() {
    [[ -f "$PROGRESS_FILE" ]] && grep -qx "$1" "$PROGRESS_FILE"
}

# --- Phase: System Setup -----------------------------------------------------
phase_system() {
    header "Phase 1: System Setup"

    if is_phase_done "system"; then
        warn "System setup already completed. Skipping. (Delete $PROGRESS_FILE to re-run)"
        return 0
    fi

    # Set hostname
    if [[ -n "${HOSTNAME:-}" && "$HOSTNAME" != "$(hostname)" ]]; then
        info "Setting hostname to: $HOSTNAME"
        hostnamectl set-hostname "$HOSTNAME"
        log "Hostname set to $HOSTNAME"
    fi

    # Update system
    info "Updating package lists and upgrading system..."
    apt-get update -y
    apt-get upgrade -y
    log "System updated."

    # Install essential packages
    info "Installing essential packages..."
    apt-get install -y \
        build-essential \
        git \
        curl \
        wget \
        htop \
        tmux \
        lm-sensors \
        net-tools \
        jq \
        unzip \
        software-properties-common
    log "Essential packages installed."

    # Disable unnecessary services
    if [[ -n "${DISABLE_SERVICES:-}" ]]; then
        for svc in $DISABLE_SERVICES; do
            if systemctl is-enabled "$svc" &>/dev/null; then
                info "Disabling service: $svc"
                systemctl disable "$svc" --now 2>/dev/null || warn "Could not disable $svc"
            else
                info "Service $svc not found or already disabled."
            fi
        done
        log "Unnecessary services disabled."
    fi

    # Configure lid close behavior
    if [[ "${IGNORE_LID_CLOSE:-no}" == "yes" ]]; then
        info "Configuring lid close to do nothing..."
        local logind_conf="/etc/systemd/logind.conf"
        # Remove existing lid switch lines and add our config
        sed -i '/^HandleLidSwitch/d' "$logind_conf"
        sed -i '/^#HandleLidSwitch/d' "$logind_conf"
        cat >> "$logind_conf" <<EOF
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
        systemctl restart systemd-logind
        log "Lid close configured to ignore."
    fi

    # Run sensors-detect non-interactively
    info "Detecting sensors..."
    yes "" | sensors-detect --auto &>/dev/null || true
    log "Sensor detection complete."

    mark_phase_done "system"
}

# --- Phase: NVIDIA Drivers ---------------------------------------------------
phase_nvidia() {
    header "Phase 2: NVIDIA GPU Drivers"

    if is_phase_done "nvidia"; then
        warn "NVIDIA setup already completed. Skipping."
        return 0
    fi

    # Check for NVIDIA GPU
    if ! lspci | grep -qi nvidia; then
        warn "No NVIDIA GPU detected. Skipping NVIDIA driver installation."
        mark_phase_done "nvidia"
        return 0
    fi

    # Check if driver is already installed and working
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        log "NVIDIA driver already installed and working."
        nvidia-smi | tee -a "$LOG_FILE"
        mark_phase_done "nvidia"
        return 0
    fi

    # Add NVIDIA PPA
    info "Adding NVIDIA drivers PPA..."
    add-apt-repository ppa:graphics-drivers/ppa -y
    apt-get update -y

    # Install driver
    if [[ "${NVIDIA_DRIVER:-auto}" == "auto" ]]; then
        info "Auto-detecting best NVIDIA driver..."
        apt-get install -y ubuntu-drivers-common
        ubuntu-drivers install
        log "NVIDIA driver auto-installed."
    else
        info "Installing NVIDIA driver version: $NVIDIA_DRIVER"
        apt-get install -y "nvidia-driver-${NVIDIA_DRIVER}"
        log "NVIDIA driver $NVIDIA_DRIVER installed."
    fi

    # Optional CUDA toolkit
    if [[ "${INSTALL_CUDA_TOOLKIT:-no}" == "yes" ]]; then
        info "Installing CUDA toolkit..."
        apt-get install -y nvidia-cuda-toolkit
        log "CUDA toolkit installed."
    fi

    mark_phase_done "nvidia"

    echo ""
    warn "╔══════════════════════════════════════════════════════════╗"
    warn "║  REBOOT REQUIRED for NVIDIA drivers to take effect.     ║"
    warn "║                                                         ║"
    warn "║  After reboot, re-run this script to continue setup:    ║"
    warn "║    sudo ./llm-server-setup.sh --all                     ║"
    warn "║                                                         ║"
    warn "║  The script will automatically skip completed phases.   ║"
    warn "╚══════════════════════════════════════════════════════════╝"
    echo ""

    read -rp "Reboot now? [Y/n]: " reboot_choice
    if [[ "${reboot_choice:-Y}" =~ ^[Yy]$ ]]; then
        log "Rebooting system..."
        reboot
    else
        warn "Remember to reboot before continuing setup!"
    fi
}

# --- Phase: Ollama -----------------------------------------------------------
phase_ollama() {
    header "Phase 3: Ollama LLM Runtime"

    if is_phase_done "ollama"; then
        warn "Ollama setup already completed. Skipping."
        return 0
    fi

    # Check NVIDIA driver is working
    if ! command -v nvidia-smi &>/dev/null || ! nvidia-smi &>/dev/null; then
        err "NVIDIA driver not detected. Please run the 'nvidia' phase first and reboot."
        exit 1
    fi

    # Install Ollama
    if command -v ollama &>/dev/null; then
        log "Ollama already installed."
    else
        info "Installing Ollama..."
        curl -fsSL https://ollama.ai/install.sh | sh
        log "Ollama installed."
    fi

    # Configure Ollama to listen on all interfaces
    info "Configuring Ollama service..."
    local ollama_service="/etc/systemd/system/ollama.service.d"
    mkdir -p "$ollama_service"
    cat > "${ollama_service}/override.conf" <<EOF
[Service]
Environment="OLLAMA_HOST=${OLLAMA_HOST:-0.0.0.0}:${OLLAMA_PORT:-11434}"
EOF

    systemctl daemon-reload
    systemctl restart ollama
    systemctl enable ollama
    log "Ollama configured to listen on ${OLLAMA_HOST:-0.0.0.0}:${OLLAMA_PORT:-11434}"

    # Wait for Ollama to be ready
    info "Waiting for Ollama to start..."
    local retries=0
    while ! curl -s "http://localhost:${OLLAMA_PORT:-11434}/api/tags" &>/dev/null; do
        sleep 2
        retries=$((retries + 1))
        if [[ $retries -ge 15 ]]; then
            err "Ollama failed to start after 30 seconds."
            exit 1
        fi
    done
    log "Ollama is running."

    # Pull models
    local models="${OLLAMA_MODELS:-interactive}"
    if [[ "$models" == "interactive" ]]; then
        pull_models_interactive
    elif [[ -n "$models" ]]; then
        for model in $models; do
            info "Pulling model: $model"
            ollama pull "$model"
            log "Model $model pulled successfully."
        done
    else
        info "No models specified in config. Skipping model pull."
    fi

    mark_phase_done "ollama"
}

pull_models_interactive() {
    header "Interactive Model Selection"

    # Detect VRAM
    local vram_mb
    vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    local vram_gb=$((vram_mb / 1024))

    echo -e "${BOLD}Detected GPU VRAM: ${GREEN}${vram_gb} GB${NC}"
    echo ""
    echo -e "${BOLD}Recommended models for your VRAM:${NC}"
    echo ""

    if [[ $vram_gb -ge 12 ]]; then
        echo "  [1] llama3.1:8b           - General chat (Q4, ~5 GB)     ★ Recommended"
        echo "  [2] qwen2.5:14b           - Advanced chat (Q4, ~9 GB)"
        echo "  [3] deepseek-coder-v2:16b - Code generation (Q4, ~10 GB) ★ Best for code"
        echo "  [4] mistral-nemo:12b      - Balanced chat (Q6, ~10 GB)"
        echo "  [5] codellama:13b         - Code generation (Q4, ~8 GB)"
        echo "  [6] llama3.1:8b-q8_0      - High-quality chat (Q8, ~8.5 GB)"
    elif [[ $vram_gb -ge 8 ]]; then
        echo "  [1] llama3.1:8b           - General chat (Q4, ~5 GB)     ★ Recommended"
        echo "  [2] mistral-nemo:12b      - Balanced chat (Q4, ~7.5 GB)"
        echo "  [3] codellama:13b         - Code generation (Q4, ~7.8 GB)"
        echo "  [4] deepseek-coder:6.7b   - Code generation (Q5, ~5 GB) ★ Best for code"
        echo "  [5] qwen2.5:7b            - Balanced chat (Q4, ~4.5 GB)"
    elif [[ $vram_gb -ge 6 ]]; then
        echo "  [1] llama3.1:8b           - General chat (Q4, ~5 GB)     ★ Recommended"
        echo "  [2] mistral:7b            - Balanced chat (Q4, ~4.5 GB)"
        echo "  [3] deepseek-coder:6.7b   - Code generation (Q4, ~4.5 GB) ★ Best for code"
        echo "  [4] qwen2.5:7b            - Balanced chat (Q4, ~4.5 GB)"
        echo "  [5] phi3:mini             - Small but capable (Q4, ~2.5 GB)"
    else
        echo "  [1] phi3:mini             - Small but capable (Q4, ~2.5 GB)"
        echo "  [2] llama3.2:3b           - Lightweight chat (Q4, ~2 GB)"
        echo "  [3] deepseek-coder:1.3b   - Lightweight code (Q4, ~1 GB)"
    fi

    echo ""
    echo "  [c] Custom model name (enter manually)"
    echo "  [s] Skip model pulling"
    echo ""

    while true; do
        read -rp "Select models to pull (comma-separated, e.g., 1,3): " selection

        if [[ "$selection" == "s" ]]; then
            info "Skipping model pull."
            return 0
        fi

        if [[ "$selection" == "c" ]]; then
            read -rp "Enter model name(s) (space-separated, e.g., llama3.1:8b mistral:7b): " custom_models
            for model in $custom_models; do
                info "Pulling model: $model"
                ollama pull "$model"
                log "Model $model pulled successfully."
            done
            return 0
        fi

        # Parse comma-separated numbers
        IFS=',' read -ra selections <<< "$selection"
        for sel in "${selections[@]}"; do
            sel=$(echo "$sel" | tr -d ' ')
            local model_name
            model_name=$(get_model_by_selection "$vram_gb" "$sel")
            if [[ -n "$model_name" ]]; then
                info "Pulling model: $model_name"
                ollama pull "$model_name"
                log "Model $model_name pulled successfully."
            else
                warn "Invalid selection: $sel"
            fi
        done
        break
    done
}

get_model_by_selection() {
    local vram_gb=$1
    local selection=$2

    if [[ $vram_gb -ge 12 ]]; then
        case $selection in
            1) echo "llama3.1:8b" ;;
            2) echo "qwen2.5:14b" ;;
            3) echo "deepseek-coder-v2:16b" ;;
            4) echo "mistral-nemo:12b" ;;
            5) echo "codellama:13b" ;;
            6) echo "llama3.1:8b-q8_0" ;;
            *) echo "" ;;
        esac
    elif [[ $vram_gb -ge 8 ]]; then
        case $selection in
            1) echo "llama3.1:8b" ;;
            2) echo "mistral-nemo:12b" ;;
            3) echo "codellama:13b" ;;
            4) echo "deepseek-coder:6.7b" ;;
            5) echo "qwen2.5:7b" ;;
            *) echo "" ;;
        esac
    elif [[ $vram_gb -ge 6 ]]; then
        case $selection in
            1) echo "llama3.1:8b" ;;
            2) echo "mistral:7b" ;;
            3) echo "deepseek-coder:6.7b" ;;
            4) echo "qwen2.5:7b" ;;
            5) echo "phi3:mini" ;;
            *) echo "" ;;
        esac
    else
        case $selection in
            1) echo "phi3:mini" ;;
            2) echo "llama3.2:3b" ;;
            3) echo "deepseek-coder:1.3b" ;;
            *) echo "" ;;
        esac
    fi
}

# --- Phase: Docker -----------------------------------------------------------
phase_docker() {
    header "Phase 4: Docker"

    if is_phase_done "docker"; then
        warn "Docker setup already completed. Skipping."
        return 0
    fi

    if [[ "${INSTALL_OPEN_WEBUI:-yes}" != "yes" ]]; then
        info "Open WebUI not requested. Skipping Docker installation."
        mark_phase_done "docker"
        return 0
    fi

    if command -v docker &>/dev/null; then
        log "Docker already installed."
    else
        info "Installing Docker..."
        # Install Docker using official convenience script
        curl -fsSL https://get.docker.com | sh

        # Add current sudo user to docker group
        local real_user="${SUDO_USER:-$USER}"
        if [[ "$real_user" != "root" ]]; then
            usermod -aG docker "$real_user"
            info "Added user '$real_user' to docker group."
        fi

        systemctl enable docker
        systemctl start docker
        log "Docker installed and running."
    fi

    mark_phase_done "docker"
}

# --- Phase: Open WebUI -------------------------------------------------------
phase_webui() {
    header "Phase 5: Open WebUI"

    if is_phase_done "webui"; then
        warn "Open WebUI setup already completed. Skipping."
        return 0
    fi

    if [[ "${INSTALL_OPEN_WEBUI:-yes}" != "yes" ]]; then
        info "Open WebUI not requested. Skipping."
        mark_phase_done "webui"
        return 0
    fi

    if ! command -v docker &>/dev/null; then
        err "Docker is not installed. Run the 'docker' phase first."
        exit 1
    fi

    # Check if container already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^open-webui$"; then
        warn "Open WebUI container already exists."
        read -rp "Recreate it? [y/N]: " recreate
        if [[ "${recreate:-N}" =~ ^[Yy]$ ]]; then
            docker stop open-webui 2>/dev/null || true
            docker rm open-webui 2>/dev/null || true
        else
            mark_phase_done "webui"
            return 0
        fi
    fi

    local webui_port="${OPEN_WEBUI_PORT:-3000}"
    local ollama_port="${OLLAMA_PORT:-11434}"

    info "Deploying Open WebUI on port $webui_port (using host networking)..."
    docker run -d \
        --network=host \
        -e OLLAMA_BASE_URL="http://127.0.0.1:${ollama_port}" \
        -e PORT="${webui_port}" \
        -v open-webui:/app/backend/data \
        --name open-webui \
        --restart always \
        ghcr.io/open-webui/open-webui:main

    log "Open WebUI deployed at http://localhost:${webui_port}"
    info "Create your admin account by visiting the URL above."

    mark_phase_done "webui"
}

# --- Phase: Tailscale --------------------------------------------------------
phase_tailscale() {
    header "Phase 6: Tailscale VPN"

    if is_phase_done "tailscale"; then
        warn "Tailscale setup already completed. Skipping."
        return 0
    fi

    if [[ "${INSTALL_TAILSCALE:-yes}" != "yes" ]]; then
        info "Tailscale not requested. Skipping."
        mark_phase_done "tailscale"
        return 0
    fi

    if command -v tailscale &>/dev/null; then
        log "Tailscale already installed."
    else
        info "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
        log "Tailscale installed."
    fi

    # Check if already connected
    if tailscale status &>/dev/null; then
        log "Tailscale is already connected."
        tailscale status | tee -a "$LOG_FILE"
    else
        info "Starting Tailscale authentication..."
        echo ""
        echo -e "${BOLD}A browser window or URL will appear to authenticate.${NC}"
        echo -e "${BOLD}If running headless, copy the URL and open it on another device.${NC}"
        echo ""
        tailscale up
        log "Tailscale connected."
        echo ""
        info "Your Tailscale IP:"
        tailscale ip -4 | tee -a "$LOG_FILE"
    fi

    mark_phase_done "tailscale"
}

# --- Phase: Security ---------------------------------------------------------
phase_security() {
    header "Phase 7: Security Hardening"

    if is_phase_done "security"; then
        warn "Security setup already completed. Skipping."
        return 0
    fi

    # UFW Firewall
    if [[ "${CONFIGURE_UFW:-yes}" == "yes" ]]; then
        info "Configuring UFW firewall..."
        apt-get install -y ufw

        ufw default deny incoming
        ufw default allow outgoing

        # Always allow SSH
        ufw allow ssh

        # Allow Tailscale interface if installed
        if command -v tailscale &>/dev/null; then
            ufw allow in on tailscale0
            info "UFW: Allowed all traffic on Tailscale interface."
        fi

        # Allow Ollama port on Tailscale only (if Tailscale is installed)
        # Otherwise allow it on all interfaces
        local ollama_port="${OLLAMA_PORT:-11434}"
        local webui_port="${OPEN_WEBUI_PORT:-3000}"

        if command -v tailscale &>/dev/null; then
            info "UFW: Ollama ($ollama_port) and WebUI ($webui_port) accessible via Tailscale only."
        else
            ufw allow "$ollama_port"/tcp
            ufw allow "$webui_port"/tcp
            warn "UFW: Ollama and WebUI ports open on all interfaces (no Tailscale)."
        fi

        ufw --force enable
        log "UFW firewall configured and enabled."
    fi

    # Fail2ban
    if [[ "${INSTALL_FAIL2BAN:-yes}" == "yes" ]]; then
        info "Installing fail2ban..."
        apt-get install -y fail2ban

        # Create local config
        cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

        systemctl enable fail2ban
        systemctl restart fail2ban
        log "Fail2ban installed and configured."
    fi

    # SSH key-only authentication
    if [[ "${SSH_KEY_ONLY:-no}" == "yes" ]]; then
        warn "Disabling SSH password authentication (key-only mode)..."
        warn "Make sure you have SSH keys configured, or you may lock yourself out!"
        echo ""
        read -rp "Have you already set up SSH key authentication? [y/N]: " ssh_ready
        if [[ "${ssh_ready:-N}" =~ ^[Yy]$ ]]; then
            sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
            sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
            systemctl restart sshd
            log "SSH password authentication disabled."
        else
            warn "Skipping SSH hardening. Set up keys first, then re-run with --phase security."
        fi
    fi

    mark_phase_done "security"
}

# --- Summary -----------------------------------------------------------------
print_summary() {
    header "Setup Complete! 🎉"

    echo -e "${BOLD}Machine:${NC}  $(hostname)"
    echo ""

    # NVIDIA info
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        echo -e "${BOLD}GPU:${NC}"
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader | while read -r line; do
            echo "  $line"
        done
        echo ""
    fi

    # Ollama status
    if command -v ollama &>/dev/null; then
        echo -e "${BOLD}Ollama:${NC}"
        echo "  API:    http://localhost:${OLLAMA_PORT:-11434}"
        echo "  Models:"
        ollama list 2>/dev/null | sed 's/^/    /' || echo "    (none pulled yet)"
        echo ""
    fi

    # Open WebUI
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^open-webui$"; then
        echo -e "${BOLD}Open WebUI:${NC}"
        echo "  URL: http://localhost:${OPEN_WEBUI_PORT:-3000}"
        echo ""
    fi

    # Tailscale
    if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
        echo -e "${BOLD}Tailscale:${NC}"
        echo "  IP:   $(tailscale ip -4 2>/dev/null || echo 'N/A')"
        echo "  Name: $(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' 2>/dev/null | sed 's/\.$//' || echo 'N/A')"
        echo ""
    fi

    # Firewall
    if ufw status 2>/dev/null | grep -q "active"; then
        echo -e "${BOLD}Firewall:${NC} Active"
        echo ""
    fi

    echo -e "${BOLD}Useful commands:${NC}"
    echo "  nvidia-smi                  # GPU status"
    echo "  ollama list                 # List installed models"
    echo "  ollama pull <model>         # Download a new model"
    echo "  ollama run <model>          # Chat with a model in terminal"
    echo "  docker logs open-webui      # Open WebUI logs"
    echo "  tailscale status            # VPN status"
    echo "  sudo ufw status             # Firewall rules"
    echo "  sensors                     # CPU/GPU temperatures"
    echo ""
    echo -e "${BOLD}Connect from VS Code:${NC}"
    echo "  Install the Continue extension, then configure:"
    echo "    API Base: http://$(tailscale ip -4 2>/dev/null || echo '<this-machine-ip>'):${OLLAMA_PORT:-11434}"
    echo ""
    echo -e "${BOLD}Log file:${NC} $LOG_FILE"
}

# --- Main --------------------------------------------------------------------
usage() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all              Run all phases in order"
    echo "  --phase <name>     Run a specific phase (can be repeated)"
    echo "  --config <path>    Path to config file (default: ./llm-server.conf)"
    echo "  --status           Show current setup progress"
    echo "  --reset            Clear progress tracking (allows re-run of all phases)"
    echo "  --help             Show this help message"
    echo ""
    echo "Phases:"
    echo "  system     System setup (packages, hostname, lid close, services)"
    echo "  nvidia     NVIDIA GPU driver installation"
    echo "  ollama     Ollama LLM runtime and model pulling"
    echo "  docker     Docker engine installation"
    echo "  webui      Open WebUI deployment"
    echo "  tailscale  Tailscale VPN setup"
    echo "  security   UFW firewall, fail2ban, SSH hardening"
    echo ""
    echo "Examples:"
    echo "  sudo $0 --all                        # Full setup"
    echo "  sudo $0 --phase system --phase nvidia # Only system + NVIDIA"
    echo "  sudo $0 --phase ollama               # Only Ollama setup"
    echo "  sudo $0 --status                     # Check progress"
}

show_status() {
    header "Setup Progress"
    local all_phases=("system" "nvidia" "ollama" "docker" "webui" "tailscale" "security")
    for phase in "${all_phases[@]}"; do
        if is_phase_done "$phase"; then
            echo -e "  ${GREEN}[✓]${NC} $phase"
        else
            echo -e "  ${RED}[ ]${NC} $phase"
        fi
    done
    echo ""
}

run_phase() {
    case "$1" in
        system)    phase_system ;;
        nvidia)    phase_nvidia ;;
        ollama)    phase_ollama ;;
        docker)    phase_docker ;;
        webui)     phase_webui ;;
        tailscale) phase_tailscale ;;
        security)  phase_security ;;
        *)
            err "Unknown phase: $1"
            usage
            exit 1
            ;;
    esac
}

main() {
    local phases=()
    local run_all=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                run_all=true
                shift
                ;;
            --phase)
                if [[ -z "${2:-}" ]]; then
                    err "--phase requires a phase name."
                    exit 1
                fi
                phases+=("$2")
                shift 2
                ;;
            --config)
                if [[ -z "${2:-}" ]]; then
                    err "--config requires a file path."
                    exit 1
                fi
                CONF_FILE="$2"
                shift 2
                ;;
            --status)
                show_status
                exit 0
                ;;
            --reset)
                rm -f "$PROGRESS_FILE"
                log "Progress tracking reset."
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                err "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Must be root
    check_root
    check_ubuntu

    # Create log file
    touch "$LOG_FILE"

    header "LLM Server Setup"
    info "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    info "Script directory: $SCRIPT_DIR"

    # Load config
    load_config "$CONF_FILE"

    # Determine what to run
    if $run_all; then
        phases=("system" "nvidia" "ollama" "docker" "webui" "tailscale" "security")
    fi

    if [[ ${#phases[@]} -eq 0 ]]; then
        err "No phases specified. Use --all or --phase <name>."
        echo ""
        usage
        exit 1
    fi

    info "Phases to run: ${phases[*]}"
    echo ""

    # Run phases
    for phase in "${phases[@]}"; do
        run_phase "$phase"
    done

    # Print summary
    print_summary
}

main "$@"
