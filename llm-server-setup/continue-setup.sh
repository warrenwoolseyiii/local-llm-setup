#!/usr/bin/env bash
# =============================================================================
# Continue Extension Setup Script (YAML format — Continue v1.2+)
# =============================================================================
# Manages the VS Code Continue extension configuration for connecting to
# Ollama LLM servers. Supports first-time setup, adding models, removing
# models, and listing current configuration.
#
# Usage:
#   ./continue-setup.sh init    --host <host> --model <model> [--name <name>] [--roles <roles>]
#   ./continue-setup.sh add     --host <host> --model <model> [--name <name>] [--roles <roles>]
#   ./continue-setup.sh remove  --name <name>
#   ./continue-setup.sh list
#   ./continue-setup.sh --help
#
# Requires: python3 with PyYAML (pip3 install pyyaml)
# =============================================================================

set -euo pipefail

# --- Constants ---------------------------------------------------------------
CONTINUE_DIR="${HOME}/.continue"
CONFIG_FILE="${CONTINUE_DIR}/config.yaml"
DEFAULT_PORT="11434"
DEFAULT_PROVIDER="ollama"
DEFAULT_ROLES="chat,edit,apply"

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# --- Logging -----------------------------------------------------------------
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

# --- Dependency Check --------------------------------------------------------
check_python() {
    if ! command -v python3 &>/dev/null; then
        err "python3 is required but not installed."
        exit 1
    fi
    if ! python3 -c "import yaml" 2>/dev/null; then
        err "PyYAML is required but not installed."
        echo ""
        echo "Install it with:"
        echo "  pip3 install pyyaml"
        exit 1
    fi
}

# --- Helpers -----------------------------------------------------------------

build_api_base() {
    local host="$1"
    local port="${2:-$DEFAULT_PORT}"

    host="${host%/}"

    if [[ "$host" =~ ^https?:// ]]; then
        if [[ "$host" =~ :[0-9]+$ ]]; then
            echo "$host"
        else
            echo "${host}:${port}"
        fi
    else
        if [[ "$host" =~ :[0-9]+$ ]]; then
            echo "http://${host}"
        else
            echo "http://${host}:${port}"
        fi
    fi
}

# --- Commands ----------------------------------------------------------------

cmd_add() {
    local host=""
    local model=""
    local name=""
    local port="$DEFAULT_PORT"
    local provider="$DEFAULT_PROVIDER"
    local roles="$DEFAULT_ROLES"
    local is_init=false

    if [[ "${1:-}" == "--init" ]]; then
        is_init=true
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host|-h)
                host="$2"; shift 2 ;;
            --model|-m)
                model="$2"; shift 2 ;;
            --name|-n)
                name="$2"; shift 2 ;;
            --port|-p)
                port="$2"; shift 2 ;;
            --provider)
                provider="$2"; shift 2 ;;
            --roles|-r)
                roles="$2"; shift 2 ;;
            *)
                err "Unknown option for add: $1"
                usage; exit 1 ;;
        esac
    done

    if [[ -z "$host" ]]; then
        err "Missing required argument: --host"
        echo "  Example: --host w_rog_0_llm_server  or  --host 100.64.0.1"
        exit 1
    fi
    if [[ -z "$model" ]]; then
        err "Missing required argument: --model"
        echo "  Example: --model llama3.1:8b  or  --model deepseek-coder-v2:16b"
        exit 1
    fi

    local api_base
    api_base=$(build_api_base "$host" "$port")

    if [[ -z "$name" ]]; then
        name="$model"
    fi

    # Ensure config directory exists
    mkdir -p "$CONTINUE_DIR"

    # Run Python to add the model
    local output
    output=$(python3 << PYTHON
import yaml
import sys
import os

config_file = os.path.expanduser('$CONFIG_FILE')
model_name = '''$name'''
model_id = '''$model'''
provider = '''$provider'''
api_base = '''$api_base'''
roles = [r.strip() for r in '''$roles'''.split(',')]

# Load or create config
if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f) or {}
else:
    config = {}

# Ensure base structure
config.setdefault('name', 'Main Config')
config.setdefault('version', '1.0.0')
config.setdefault('schema', 'v1')
config.setdefault('models', [])

# Check for duplicate name
for m in config['models']:
    if m.get('name') == model_name:
        print(f'ERROR:A model with name "{model_name}" already exists. Use --name to set a different name, or remove it first.')
        sys.exit(0)

# Build the new model entry
entry = {
    'name': model_name,
    'provider': provider,
    'model': model_id,
    'apiBase': api_base,
    'roles': roles,
}

config['models'].append(entry)

with open(config_file, 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)

print(f'OK:Added model: "{model_name}" ({model_id} @ {api_base}) roles=[{", ".join(roles)}]')
PYTHON
    ) || true

    # Process output
    if [[ "$output" == ERROR:* ]]; then
        err "${output#ERROR:}"
        exit 1
    elif [[ "$output" == OK:* ]]; then
        log "${output#OK:}"
    else
        err "Unexpected output: $output"
        exit 1
    fi

    if $is_init; then
        echo ""
        log "Continue extension initialized!"
    fi

    echo ""
    info "Config file: $CONFIG_FILE"
    info "Restart VS Code or reload the Continue extension to apply changes."
}

cmd_remove() {
    local name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name|-n)
                name="$2"; shift 2 ;;
            *)
                err "Unknown option for remove: $1"
                usage; exit 1 ;;
        esac
    done

    if [[ -z "$name" ]]; then
        err "Missing required argument: --name"
        echo ""
        echo "Use './continue-setup.sh list' to see current model names."
        exit 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        err "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    local output
    output=$(python3 << PYTHON
import yaml
import sys

config_file = '$CONFIG_FILE'
target_name = '''$name'''

with open(config_file, 'r') as f:
    config = yaml.safe_load(f) or {}

models = config.get('models', [])
new_models = [m for m in models if m.get('name') != target_name]

if len(new_models) == len(models):
    print(f'ERROR:No model found with name: "{target_name}"')
    sys.exit(0)

config['models'] = new_models

with open(config_file, 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)

print(f'OK:Removed model: "{target_name}"')
PYTHON
    ) || true

    if [[ "$output" == ERROR:* ]]; then
        err "${output#ERROR:}"
        exit 1
    elif [[ "$output" == OK:* ]]; then
        log "${output#OK:}"
    fi

    echo ""
    info "Config file: $CONFIG_FILE"
    info "Restart VS Code or reload the Continue extension to apply changes."
}

cmd_list() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "Config file not found: $CONFIG_FILE"
        echo ""
        echo "Create one with:"
        echo "  ./continue-setup.sh init --host <host> --model <model>"
        return 0
    fi

    echo ""
    echo -e "${CYAN}${BOLD}Continue Extension Configuration${NC}"
    echo -e "${CYAN}Config: ${CONFIG_FILE}${NC}"
    echo ""

    python3 << PYTHON
import yaml

config_file = '$CONFIG_FILE'

with open(config_file, 'r') as f:
    config = yaml.safe_load(f) or {}

models = config.get('models', [])

if not models:
    print('  (no models configured)')
    print()
    print('Add one with:')
    print('  ./continue-setup.sh add --host <host> --model <model>')
else:
    for m in models:
        name = m.get('name', '(unnamed)')
        provider = m.get('provider', '?')
        model = m.get('model', '?')
        api_base = m.get('apiBase', '(default/local)')
        roles = ', '.join(m.get('roles', []))
        print(f'  {name}')
        print(f'    Provider: {provider}')
        print(f'    Model:    {model}')
        print(f'    API Base: {api_base}')
        print(f'    Roles:    {roles}')
        print()
PYTHON
}

# --- Usage -------------------------------------------------------------------
usage() {
    echo ""
    echo -e "${BOLD}Continue Extension Setup Script (YAML — v1.2+)${NC}"
    echo ""
    echo "Manages the VS Code Continue extension config (~/.continue/config.yaml)"
    echo "for connecting to Ollama LLM servers."
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  $0 <command> [options]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  init       First-time setup — creates config and adds a model"
    echo "  add        Add a model to the existing config"
    echo "  remove     Remove a model by its name"
    echo "  list       Show current configuration"
    echo ""
    echo -e "${BOLD}Options for init / add:${NC}"
    echo "  --host, -h <host>       Ollama server hostname, IP, or URL (required)"
    echo "  --model, -m <model>     Ollama model name (required)"
    echo "  --name, -n <name>       Display name (defaults to model name)"
    echo "  --port, -p <port>       Ollama port (default: 11434)"
    echo "  --provider <provider>   Provider name (default: ollama)"
    echo "  --roles, -r <roles>     Comma-separated roles (default: chat,edit,apply)"
    echo "                          Available: chat, edit, apply, autocomplete, embed"
    echo ""
    echo -e "${BOLD}Options for remove:${NC}"
    echo "  --name, -n <name>       Name of the model to remove (required)"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo ""
    echo "  # First-time setup with a chat model"
    echo "  $0 init --host w_rog_0_llm_server --model llama3.1:8b --name \"Llama 3.1 8B\""
    echo ""
    echo "  # Add a code autocomplete model"
    echo "  $0 add --host w_rog_0_llm_server --model qwen2.5-coder:1.5b-base \\"
    echo "         --name \"Qwen Coder\" --roles autocomplete"
    echo ""
    echo "  # Add an embedding model"
    echo "  $0 add --host w_rog_0_llm_server --model nomic-embed-text:latest \\"
    echo "         --name \"Nomic Embed\" --roles embed"
    echo ""
    echo "  # Add using a Tailscale IP with custom port"
    echo "  $0 add --host 100.64.0.2 --model llama3.1:8b --port 8080"
    echo ""
    echo "  # Remove a model"
    echo "  $0 remove --name \"Qwen Coder\""
    echo ""
    echo "  # List current config"
    echo "  $0 list"
    echo ""
}

# --- Main --------------------------------------------------------------------
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    check_python

    local command="$1"
    shift

    case "$command" in
        init)
            cmd_add --init "$@"
            ;;
        add)
            cmd_add "$@"
            ;;
        remove)
            cmd_remove "$@"
            ;;
        list)
            cmd_list
            ;;
        --help|-h|help)
            usage
            exit 0
            ;;
        *)
            err "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
