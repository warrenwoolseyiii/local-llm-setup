# Ollama Usage Guide

Guide for pulling models, selecting models by VRAM, and using Ollama after server setup.

> **Prerequisite:** Complete the server setup in [`llm-server-setup/`](../llm-server-setup/llm-server-setup-README.md) first.

## Pulling Models

```bash
# Pull a model
ollama pull <model-name>

# List installed models
ollama list

# Remove a model
ollama rm <model-name>

# Chat with a model in terminal
ollama run <model-name>
```

## Model Selection by VRAM

VRAM is the primary constraint for model selection. Use `nvidia-smi` to check available VRAM.

### 6 GB VRAM

| Model | Parameters | Quantization | VRAM Usage | Notes |
|-------|-----------|--------------|------------|-------|
| `llama3.1:8b` | 8B | Q4_K_M | ~5.0 GB | Good general chat |
| `mistral:7b` | 7B | Q4_K_M | ~4.5 GB | Balanced chat |
| `deepseek-coder:6.7b` | 6.7B | Q4_K_M | ~4.5 GB | Good for code |
| `qwen2.5:7b` | 7B | Q4_K_M | ~4.5 GB | Balanced chat |
| `phi3:mini` | 3.8B | Q4_K_M | ~2.5 GB | Small but capable |

### 8 GB VRAM

| Model | Parameters | Quantization | VRAM Usage | Notes |
|-------|-----------|--------------|------------|-------|
| `llama3.1:8b` | 8B | Q5_K_M | ~5.8 GB | Very good general chat |
| `mistral-nemo:12b` | 12B | Q4_K_M | ~7.5 GB | Very good chat |
| `codellama:13b` | 13B | Q4_K_M | ~7.8 GB | Good for code |
| `deepseek-coder:6.7b` | 6.7B | Q5_K_M | ~5.0 GB | Good for code |

### 12+ GB VRAM

| Model | Parameters | Quantization | VRAM Usage | Notes |
|-------|-----------|--------------|------------|-------|
| `llama3.1:8b` | 8B | Q8_0 | ~8.5 GB | Excellent quality |
| `qwen2.5:14b` | 14B | Q4_K_M | ~9.0 GB | Very good chat |
| `deepseek-coder-v2:16b` | 16B | Q4_K_M | ~10 GB | Excellent for code |
| `mistral-nemo:12b` | 12B | Q6_K | ~10 GB | Excellent chat |

### Quantization Guide

- **Q4_K_M** — Best balance of quality vs size (sweet spot)
- **Q5_K_M** — Noticeable quality improvement, ~20% more VRAM
- **Q8_0** — Near-original quality, if VRAM allows
- **Q3_K_M / Q2_K** — Quality tradeoff; use only to fit a larger model

## Testing Inference

```bash
# Verify GPU is accessible
nvidia-smi

# Test a model via CLI
ollama run llama3.1:8b "Hello, what can you do?"

# Test via API
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"Hello!"}]}'
```
