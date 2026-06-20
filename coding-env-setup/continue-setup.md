# Continue — VSCode Setup for Local LLM Chat

Use the [Continue](https://continue.dev/) VSCode extension as a token-free, ChatGPT-like chat interface powered by our local LLM server.

> **Use case:** Quick ask/how-to questions, script generation, brainstorming. Continue will NOT edit files in your workspace — it's a chat-only interface.

## Prerequisites

- VSCode installed
- [Tailscale](https://tailscale.com/) connected to the same tailnet as the LLM server
- LLM server running Ollama (see [`llm-server-setup/`](../llm-server-setup/llm-server-setup-README.md))

## 1. Install the Extension

1. Open VSCode
2. Go to Extensions (`Cmd+Shift+X`)
3. Search for **Continue**
4. Install the extension by **Continue**
5. Restart VSCode if prompted

## 2. Find Your Server Address

You need the Tailscale IP or MagicDNS hostname of the LLM server.

```bash
# On the LLM server, or from any tailnet device:
tailscale status
```

Look for the LLM server entry. You'll see either:
- A Tailscale IP like `100.x.y.z`
- A MagicDNS hostname like `llm-server`

> **Note:** Your Tailscale IP will be unique to your tailnet. Replace the placeholder in the config below with your actual address.

## 3. Configure Continue

Continue's config file lives at:

```
~/.continue/config.yaml
```

If it doesn't exist, Continue creates it on first launch. Replace its contents with:

```yaml
name: Main Config
version: 1.0.0
schema: v1
models:
  - name: Gemma 4
    provider: ollama
    model: gemma4:e4b
    apiBase: http://<YOUR_TAILSCALE_IP>:11434
    roles:
      - chat
```

### Configuration Notes

| Field | Description |
|-------|-------------|
| `name` | Display name shown in the Continue chat dropdown |
| `provider` | Must be `ollama` for our server |
| `model` | The Ollama model tag (must be pulled on the server) |
| `apiBase` | `http://<TAILSCALE_IP>:11434` — the Ollama API endpoint |
| `roles` | Use `chat` only. We don't use `edit` or `apply` since this is chat-only |

### Example with MagicDNS

If your LLM server's hostname is `llm-server` and MagicDNS is enabled:

```yaml
models:
  - name: Gemma 4
    provider: ollama
    model: gemma4:e4b
    apiBase: http://llm-server:11434
    roles:
      - chat
```

### Example with Tailscale IP

```yaml
models:
  - name: Gemma 4
    provider: ollama
    model: gemma4:e4b
    apiBase: http://100.102.234.36:11434
    roles:
      - chat
```

## 4. Verify Connection

1. Open the Continue panel in VSCode (click the Continue icon in the sidebar, or `Cmd+L`)
2. Select your model from the dropdown
3. Type a message and confirm you get a response

If it fails, verify:
```bash
# From your local machine, test the Ollama API directly:
curl http://<YOUR_TAILSCALE_IP>:11434/api/tags
```

If that times out, check that Tailscale is connected and the Ollama service is running on the server.

## 5. Switching Models

To use a different model, change the `model` field to any model pulled on the server. Check available models:

```bash
curl http://<YOUR_TAILSCALE_IP>:11434/api/tags
```

You can also list multiple models in the config:

```yaml
models:
  - name: Gemma 4
    provider: ollama
    model: gemma4:e4b
    apiBase: http://llm-server:11434
    roles:
      - chat
  - name: Qwen 2.5 14B
    provider: ollama
    model: qwen2.5:14b
    apiBase: http://llm-server:11434
    roles:
      - chat
```

Continue will let you switch between them in the chat dropdown.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No response / timeout | Check `tailscale status` — are you connected? |
| Connection refused | Verify Ollama is running: `ssh` into server, run `systemctl status ollama` |
| Model not found | Ensure the model is pulled on the server: `ollama list` |
| Slow responses | Normal for larger models. Check GPU usage with `nvidia-smi` on the server |

## What Continue is Good For

- ✅ Quick questions and explanations
- ✅ Generating scripts, snippets, configs
- ✅ Brainstorming and rubber-ducking
- ✅ Token-free — no API costs

## What Continue is NOT For (in this setup)

- ❌ Editing files in your workspace
- ❌ Multi-file refactoring
- ❌ Codebase-aware context (use Copilot / Roo for that)
