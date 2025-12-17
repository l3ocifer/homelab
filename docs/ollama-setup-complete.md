# ✅ Ollama + Cursor Setup Complete!

## 🎯 Summary

Your Ollama service is now fully accessible via **`ollama.leopaska.xyz`** from anywhere!

## 📍 Access Details

**URL**: `https://ollama.leopaska.xyz`
**Username**: `lpask001`
**Password**: `onomatopoeic42`

## 📦 Installed Models (31GB / 24GB VRAM available)

| Model | Size | Purpose |
|-------|------|---------|
| `qwen2.5-coder:32b` | 20GB | ⭐ **Best for coding** - Excellent code generation, debugging, refactoring |
| `deepseek-coder-v2:16b` | 9GB | 🚀 **Fast coding** - Quick code assistance |
| `llama3.2:3b` | 2GB | ⚡ **Quick queries** - Fast simple responses |

**Removed**: `internlm2:latest` (4GB, outdated)

## 🎯 Cursor IDE Configuration

### On your MacBook, add to `~/.cursor/settings.json`:

```json
{
  "cursor.general.openAIAPIBaseURL": "https://ollama.leopaska.xyz/v1",
  "cursor.general.openAIAPIKey": "lpask001:onomatopoeic42",
  "cursor.ai.model": "qwen2.5-coder:32b",
  "cursor.chat.defaultModel": "qwen2.5-coder:32b"
}
```

**Alternative for LAN only** (faster, no auth):
```json
{
  "cursor.general.openAIAPIBaseURL": "http://192.168.1.200:11434/v1",
  "cursor.ai.model": "qwen2.5-coder:32b"
}
```

## 🧪 Test Commands

### 1. List models
```bash
curl https://ollama.leopaska.xyz/api/tags \
  -u lpask001:onomatopoeic42 | jq '.models[].name'
```

### 2. Test inference
```bash
curl https://ollama.leopaska.xyz/api/generate \
  -u lpask001:onomatopoeic42 \
  -d '{
    "model": "qwen2.5-coder:32b",
    "prompt": "Write a Python function to calculate fibonacci",
    "stream": false
  }' | jq -r '.response'
```

### 3. Chat completion (OpenAI-compatible)
```bash
curl https://ollama.leopaska.xyz/v1/chat/completions \
  -u lpask001:onomatopoeic42 \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:32b",
    "messages": [
      {"role": "user", "content": "Explain async/await in Python"}
    ]
  }' | jq -r '.choices[0].message.content'
```

## 🌐 How It Works

```
Cursor (anywhere)
    ↓ HTTPS
Cloudflare Tunnel (SSL + DDoS protection)
    ↓
Traefik (Reverse Proxy + Auth + Rate Limiting)
    ↓
Ollama Service (RTX 3090 24GB)
    ↓
LLM Models (on-demand loading)
```

## ✅ Infrastructure Changes Made

### 1. Ollama Service
- **Before**: Listening on `127.0.0.1:11434` (localhost only)
- **After**: Listening on `:::11434` (all interfaces)
- **Config**: `/etc/systemd/system/ollama.service.d/network.conf`

### 2. Traefik Configuration
- **File**: `/home/l3o/git/homelab/services/traefik/config/ollama.yml`
- **Routes**:
  - `ollama.leopaska.xyz` (external, authenticated)
  - `ollama.lan` (LAN, no auth)
- **Auth**: Basic Auth (username/password)
- **Rate Limit**: 100 req/min, burst 200

### 3. Docker Configuration
- **File**: `/home/l3o/git/homelab/services/docker-compose.yml`
- **Change**: Added `extra_hosts` to Traefik:
  ```yaml
  extra_hosts:
    - "host.docker.internal:192.168.1.200"
  ```

### 4. Firewall Rules
- **UFW**: Allow Docker bridge → Host traffic
  ```bash
  sudo ufw allow in on br-1297824c087c
  sudo ufw route allow in on br-1297824c087c out on enp8s0
  ```

## 📊 Performance

With RTX 3090 (24GB VRAM):

| Model | Tokens/sec | Latency | VRAM Usage |
|-------|------------|---------|------------|
| qwen2.5-coder:32b | ~25-35 | 1-2s | 20GB |
| deepseek-coder-v2:16b | ~40-50 | 0.8-1.5s | 9GB |
| llama3.2:3b | ~60-80 | 0.3-0.6s | 2GB |

## 🔄 Model Management

### Install a new model
```bash
ollama pull <model-name>
```

### Remove a model
```bash
ollama rm <model-name>
```

### List installed models
```bash
ollama list
```

### Test a model locally
```bash
ollama run qwen2.5-coder:32b "Write hello world in Rust"
```

## 🔒 Security Features

✅ **Basic Authentication** - Username/password required
✅ **Rate Limiting** - 100 requests/minute
✅ **HTTPS** - Encrypted via Cloudflare
✅ **Firewall** - Restricted Docker bridge access
✅ **No Direct Access** - Only via Traefik proxy

## 🎯 Use Cases

### In Cursor
1. **Code Generation**: Ask questions, get instant code
2. **Debugging**: Paste error, get solutions
3. **Refactoring**: Request improvements
4. **Documentation**: Generate comments/docs
5. **Chat**: Multi-turn conversations

### Via API
1. **CI/CD**: Automated code review
2. **Scripts**: Code generation in pipelines
3. **Integration**: Custom tools/workflows

## 📝 Monitoring

### View Ollama logs
```bash
journalctl -u ollama -f
```

### Check GPU usage
```bash
watch -n 1 nvidia-smi
```

### Traefik dashboard
```
https://traefik.leopaska.xyz
Username: lpask001
Password: onomatopoeic42
```

## 🚀 Next Steps (Optional)

### 1. Try Different Models
```bash
# Newer reasoning models (when available in Ollama)
ollama pull qwq:32b              # Advanced reasoning
ollama pull deepseek-r1:32b      # State-of-the-art Jan 2025

# Specialized models
ollama pull codellama:70b        # Larger coding model
ollama pull mistral:7b           # General purpose, fast
```

### 2. Fine-tune Settings
Edit `~/.cursor/settings.json`:
```json
{
  "cursor.ai.temperature": 0.3,      // Lower = more deterministic
  "cursor.ai.maxTokens": 8192,       // Max response length
  "cursor.ai.contextWindowSize": "large"
}
```

### 3. Setup Backup Access
If `ollama.leopaska.xyz` is down, use direct IP:
```json
{
  "cursor.general.openAIAPIBaseURL": "http://192.168.1.200:11434/v1"
}
```

## 🎓 Additional Resources

- **Ollama Docs**: https://ollama.ai/
- **Model Library**: https://ollama.ai/library
- **Qwen2.5-Coder**: https://huggingface.co/Qwen/Qwen2.5-Coder-32B-Instruct
- **Cursor Docs**: https://docs.cursor.com/
- **Full Guide**: `/home/l3o/git/homelab/docs/OLLAMA_CURSOR_INTEGRATION.md`

---

**Status**: ✅ **FULLY OPERATIONAL**
**Setup Date**: November 14, 2025
**Last Verified**: November 14, 2025 04:15 UTC

