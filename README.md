# Local LLM Setup

This repository is a practical toolkit for two related jobs:

1. Building a local LLM server that runs Ollama, Open WebUI, Tailscale access, and basic security hardening.
2. Setting up a local coding environment with token-saving rules, RTK, and Caveman-style output compression.

The goal is simple: keep your AI workflow fast, private where possible, and cheaper to use by reducing unnecessary token usage.

## What’s Inside

- [llm-server-setup/](llm-server-setup/) - Ubuntu Server setup for a headless NVIDIA-based LLM box.
- [ollama-usage/](ollama-usage/) - Model-picking and `ollama` usage guidance after the server is up.
- [coding-env-setup/](coding-env-setup/) - Local coding-environment scripts, RTK setup, Caveman setup, and shared AI rules.
- [plans/](plans/) - Notes and planning docs for the local LLM workflow.

## Main Use Cases

### Local LLM server setup

Use the server scripts if you want a machine that can run Ollama locally, expose it safely over Tailscale, and optionally provide a browser UI through Open WebUI.

Start here:

- [llm-server-setup/llm-server-setup-README.md](llm-server-setup/llm-server-setup-README.md)
- [llm-server-setup/llm-server-setup.sh](llm-server-setup/llm-server-setup.sh)
- [llm-server-setup/llm-server.conf](llm-server-setup/llm-server.conf)

Typical flow:

1. Copy the `llm-server-setup/` folder to the target Ubuntu Server 24.04 LTS machine.
2. Edit [llm-server-setup/llm-server.conf](llm-server-setup/llm-server.conf).
3. Run `sudo ./llm-server-setup.sh --all`.
4. Reboot when prompted after NVIDIA driver installation, then rerun the script.

### Local coding environment setup

Use the coding environment scripts to make AI-assisted coding more efficient in your projects.

Start here:

- [coding-env-setup/setup-coding-env.sh](coding-env-setup/setup-coding-env.sh)
- [coding-env-setup/setup-ai-rules.sh](coding-env-setup/setup-ai-rules.sh)
- [coding-env-setup/ai-rules-setup.md](coding-env-setup/ai-rules-setup.md)
- [coding-env-setup/rtk-setup.md](coding-env-setup/rtk-setup.md)
- [coding-env-setup/caveman-setup.md](coding-env-setup/caveman-setup.md)

What it does:

- checks for and can install CodeGraph, RTK, Continue, and Caveman-related setup
- applies shared AI rules to agent config files in the current project
- encourages shorter command output and shorter assistant responses

Run it from the project you want to configure, not from this repo, because it writes files into the current working directory.

## Token Optimization

This repo is built around lowering token usage in both directions:

- **RTK** compresses shell output before it reaches the model.
- **Caveman** compresses assistant responses into shorter, denser output.
- **AI rules** keep these behaviors consistent across supported agents.

That combination is meant to make local or cloud-assisted coding sessions cheaper and less noisy.

## Ollama Model Usage

After the server is up, use [ollama-usage/README.md](ollama-usage/README.md) for model selection and testing commands.

Common commands:

```bash
ollama list
ollama pull <model-name>
ollama run <model-name>
```

## Suggested Starting Point

If you want the full stack:

1. Set up the server with [llm-server-setup/](llm-server-setup/).
2. Pull and test models using [ollama-usage/](ollama-usage/).
3. Apply token-saving rules with [coding-env-setup/](coding-env-setup/).

If you only want the coding workflow improvements, start with `coding-env-setup/`.
