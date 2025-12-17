# Ollama + Cursor Integration: Local LLM as Claude/GPT Replacement

## Executive Summary

This document outlines the best approach to serve locally-hosted LLM models from your HomeLab (Alef) to Cursor IDE, accessible from:
- **HomeLab SSH session** (current machine: 192.168.1.200)
- **MacBook on internal LAN** (same network)
- **MacBook while traveling** (remote access via Cloudflare Tunnel)

## Current Infrastructure

### Hardware
- **Server**: Alef (192.168.1.200)
- **GPU**: NVIDIA RTX 3090 24GB VRAM (CUDA 12.4)
- **VRAM**: 24GB available (23.3 GB free)
- **Service**: Ollama 0.4.2 running as systemd service
- **Models Installed**:
  - `internlm2:latest` (4.5GB)
  - `llama3.2:3b` (2GB)
  - `qwen2.5-coder:32b` (19GB) ✓ **Currently best for coding**

### Network Setup
- Internal IP: 192.168.1.200
- Cloudflare Tunnel configured
- Traefik reverse proxy available
- Ollama currently listening on: `127.0.0.1:11434` (localhost only)

---

## 🏆 Recommended Models (Claude 4.5 / GPT-5 Replacement)

### Priority 1: Best for Coding & General Purpose

#### **QwQ-32B-Preview** (NEW - November 2024)
- **Size**: 32B parameters (~20GB VRAM)
- **Strengths**:
  - Advanced reasoning with chain-of-thought
  - Exceptional at coding and problem-solving
  - Competitive with GPT-4 on many benchmarks
- **Ollama**: `ollama pull qwq:32b`
- **Status**: ✅ FITS RTX 3090

#### **DeepSeek-R1** (NEW - January 2025)
- **Size**: Available in 7B, 14B, 32B, 70B variants
- **Strengths**:
  - State-of-the-art reasoning capabilities
  - Matches o1 on AIME and MATH benchmarks
  - Excellent for complex problem-solving
- **Ollama**: `ollama pull deepseek-r1:32b` or `deepseek-r1:14b`
- **Status**: ✅ 32B FITS, 70B requires quantization

#### **Qwen2.5-Coder-32B** ⭐ (Already Installed)
- **Size**: 32B parameters (19GB)
- **Strengths**:
  - #1 for pure coding tasks
  - 92% on HumanEval benchmark
  - Excellent at code generation, debugging, refactoring
- **Ollama**: Already installed ✅
- **Status**: ✅ FITS RTX 3090, READY TO USE

### Priority 2: For Maximum Performance

#### **Llama-3.3-70B-Instruct**
- **Size**: 70B parameters (~40GB with 4-bit quantization)
- **Strengths**:
  - Multilingual, long context (128K tokens)
  - Excellent reasoning and instruction following
  - Good balance of capabilities
- **Ollama**: `ollama pull llama3.3:70b-instruct-q4_0`
- **Status**: ⚠️ Requires 4-bit quantization to fit

#### **DeepSeek-Coder-V2-Instruct**
- **Size**: 16B/236B (use 16B variant)
- **Strengths**:
  - Specialized for coding
  - Supports 338 programming languages
  - Fill-in-the-middle capability
- **Ollama**: `ollama pull deepseek-coder-v2:16b`
- **Status**: ✅ FITS RTX 3090

---

## Recommended Configuration

### Best Overall Setup (What to Do)

**Primary Model**: `qwen2.5-coder:32b` (already installed) or `QwQ-32B-Preview` (NEW)
**Backup Model**: `deepseek-r1:14b` or `deepseek-coder-v2:16b`
**Quick Model**: `llama3.2:3b` (for fast, low-resource queries)

---

## Implementation Plan

### Phase 1: Enable Network Access to Ollama

#### Step 1.1: Modify Ollama Service to Listen on All Interfaces

**Current**: Ollama listens on `127.0.0.1:11434` (localhost only)
**Goal**: Listen on `0.0.0.0:11434` or `192.168.1.200:11434`

**Option A: Environment Variable (Recommended)**

```bash
# Edit Ollama service
sudo systemctl edit ollama.service

# Add this configuration:
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

**Option B: Modify Service File Directly**

```bash
sudo nano /etc/systemd/system/ollama.service

# Add this line under [Service]:
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
```

**Apply Changes:**

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
sudo systemctl status ollama

# Verify it's listening on all interfaces
sudo netstat -tlnp | grep 11434
# Should show: 0.0.0.0:11434 or :::11434
```

#### Step 1.2: Configure Firewall

```bash
# Allow Ollama port from internal LAN
sudo ufw allow from 192.168.1.0/24 to any port 11434 proto tcp

# Verify
sudo ufw status
```

#### Step 1.3: Test Local Network Access

From your MacBook on LAN:

```bash
curl http://192.168.1.200:11434/api/tags
```

Expected response: JSON with list of models

---

### Phase 2: Add Traefik Routing (Optional but Recommended)

**Why**: SSL/TLS, authentication, rate limiting, monitoring

#### Create Traefik Configuration

File: `/home/l3o/git/homelab/services/traefik/dynamic/ollama.yml`

```yaml
http:
  routers:
    ollama-local:
      rule: "Host(`ollama.lan`) || Host(`ollama.leopaska.xyz`)"
      entryPoints:
        - web
        - websecure
      service: ollama
      middlewares:
        - api-rate-limit
        - security
      tls:
        certResolver: letsencrypt

  services:
    ollama:
      loadBalancer:
        servers:
          - url: "http://192.168.1.200:11434"
        passHostHeader: true
```

#### Update Cloudflare Tunnel Config

File: `/home/l3o/git/homelab/services/cloudflare-tunnel/config.yml`

Add this ingress rule:

```yaml
ingress:
  # ... existing rules ...

  - hostname: ollama.leopaska.xyz
    service: http://traefik:80
    originRequest:
      noTLSVerify: false
      connectTimeout: 30s

  # ... other rules ...
```

**Restart services:**

```bash
cd /home/l3o/git/homelab/services
docker-compose restart traefik
docker-compose restart cloudflare-tunnel
```

---

### Phase 3: Configure Cursor IDE

Cursor doesn't natively support custom LLM endpoints in the UI, but there are workarounds:

#### Option A: Use Cursor's OpenAI Settings (PREFERRED)

1. **Open Cursor Settings** (`Cmd+,` on Mac, `Ctrl+,` on Linux)
2. **Navigate to**: `Cursor Settings` → `Models`
3. **Add Custom OpenAI API**:
   - API Key: `ollama` (placeholder, not validated)
   - Base URL Override:
     - **On LAN**: `http://192.168.1.200:11434/v1`
     - **Remote**: `https://ollama.leopaska.xyz/v1`

#### Option B: Use Cursor's settings.json Override

File: `~/.cursor/settings.json` (on your MacBook)

Add or modify:

```json
{
  "cursor.general.enableOpenAIAPIProxy": true,
  "cursor.general.openAIAPIKey": "ollama",
  "cursor.general.openAIAPIBaseURL": "http://192.168.1.200:11434/v1",
  "cursor.ai.model": "qwen2.5-coder:32b",
  "cursor.chat.defaultModel": "qwen2.5-coder:32b"
}
```

**For Remote Access** (while traveling):

```json
{
  "cursor.general.openAIAPIBaseURL": "https://ollama.leopaska.xyz/v1",
  "cursor.ai.model": "qwen2.5-coder:32b"
}
```

#### Option C: Use Open-WebUI as Intermediary

You already have Open-WebUI configured. Use it as a proxy:

1. Access: `http://192.168.1.200:3333`
2. Configure Ollama connection
3. Get API key from Open-WebUI
4. Point Cursor to Open-WebUI endpoint

---

### Phase 4: Test & Verify

#### Test 1: Direct Ollama API

```bash
# From MacBook on LAN
curl http://192.168.1.200:11434/api/generate -d '{
  "model": "qwen2.5-coder:32b",
  "prompt": "Write a Python function to calculate fibonacci numbers",
  "stream": false
}'
```

#### Test 2: OpenAI-Compatible Endpoint

```bash
curl http://192.168.1.200:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ollama" \
  -d '{
    "model": "qwen2.5-coder:32b",
    "messages": [
      {"role": "user", "content": "Explain async/await in Python"}
    ]
  }'
```

#### Test 3: From Cursor

1. Open Cursor
2. Open Chat (Cmd+L)
3. Type a coding question
4. Verify response comes from your local model

**Indicators it's working**:
- Responses are fast (local inference)
- No internet required (can test by disabling WiFi on LAN)
- Ollama logs show requests: `journalctl -u ollama -f`

---

## Alternative: Mistral.rs vs Ollama

### Ollama Advantages (Current Setup)
✅ Easy to use and already running
✅ Systemd service integration
✅ Large model library
✅ OpenAI-compatible API
✅ Good community support
✅ Model management (`ollama pull`, `ollama list`)

### Mistral.rs Advantages
✅ **Better inference speed** (Rust-based, more optimized)
✅ **Lower memory overhead**
✅ **More control over quantization**
✅ **Support for custom GGUF models**
✅ **Better batching** for multiple requests

### Mistral.rs Disadvantages
❌ More complex setup
❌ Manual model management
❌ Less mature ecosystem
❌ Requires Rust toolchain
❌ Fewer pre-built models

### When to Use Mistral.rs

Consider switching to Mistral.rs if:
1. You need **absolute maximum inference speed**
2. You want to use **custom GGUF quantizations**
3. You need **fine-grained control** over model loading
4. You're serving **many concurrent requests**
5. You want to **minimize VRAM usage** while maintaining quality

### How to Set Up Mistral.rs

If you want to try it:

```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install mistral.rs
cargo install --git https://github.com/EricLBuehler/mistral.rs.git mistralrs-server

# Run model
mistralrs-server --port 11435 \
  --model-id TheBloke/Qwen2.5-Coder-32B-Instruct-GGUF \
  --quantization Q4_K_M
```

**Recommendation**: Stick with Ollama for now. Only switch to Mistral.rs if you hit performance bottlenecks.

---

## Performance Expectations

### Inference Speed (RTX 3090, 32B Model)

| Model | Tokens/sec | Latency (first token) | Memory Usage |
|-------|------------|----------------------|--------------|
| Qwen2.5-Coder-32B | ~25-35 | ~1-2s | 19GB |
| DeepSeek-R1-32B | ~20-30 | ~1.5-2.5s | 20GB |
| Llama-3.3-70B-Q4 | ~12-18 | ~2-3s | 40GB |
| DeepSeek-Coder-V2-16B | ~40-50 | ~0.8-1.5s | 10GB |

**Note**: These are approximate. Actual performance depends on prompt length, context size, and system load.

---

## Security Considerations

### Internal LAN
✅ Safe - protected by router firewall
✅ No authentication required
✅ Use HTTP (no SSL overhead on LAN)

### Remote Access (Cloudflare Tunnel)
⚠️ **MUST** implement authentication
⚠️ **MUST** use SSL/TLS (Cloudflare handles this)
⚠️ Consider rate limiting

**Recommended Middleware** (Traefik):
- Basic Auth or API key
- Rate limiting: 100 req/min per IP
- IP whitelist if possible

**Example Traefik Middleware**:

```yaml
http:
  middlewares:
    ollama-auth:
      basicAuth:
        users:
          - "leo:$apr1$..." # Use htpasswd to generate

    ollama-rate-limit:
      rateLimit:
        average: 100
        burst: 150
        period: 1m
```

---

## Cost-Benefit Analysis

### Running Local LLMs

**Pros**:
✅ **Privacy**: All data stays local
✅ **Cost**: No API fees ($0/month vs $20-200/month)
✅ **Speed**: Local inference, no network latency
✅ **Offline**: Works without internet
✅ **Customization**: Full control over models
✅ **Unlimited**: No rate limits or token quotas

**Cons**:
❌ **Power**: ~350W continuous (RTX 3090)
❌ **Setup**: Initial configuration required
❌ **Maintenance**: Model updates, service uptime
❌ **Quality**: Still behind Claude 4.5 / GPT-4 (but catching up fast)
❌ **Hardware**: Requires capable GPU

**Break-even**: If you spend >$20/month on Claude/GPT APIs, local LLMs pay for themselves.

---

## Quick Start Guide

### 1. Enable Ollama Network Access (5 minutes)

```bash
ssh l3o@192.168.1.200
sudo systemctl edit ollama.service
```

Add:
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
```

Save and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### 2. Install Best Model (10 minutes)

```bash
# Option A: QwQ-32B (newer, better reasoning)
ollama pull qwq:32b

# Option B: DeepSeek-R1-32B (newest, January 2025)
ollama pull deepseek-r1:32b

# Option C: Keep using Qwen2.5-Coder (already installed)
# No action needed
```

### 3. Test from MacBook (1 minute)

```bash
curl http://192.168.1.200:11434/api/tags
```

### 4. Configure Cursor (2 minutes)

Add to `~/.cursor/settings.json`:

```json
{
  "cursor.general.openAIAPIBaseURL": "http://192.168.1.200:11434/v1",
  "cursor.ai.model": "qwen2.5-coder:32b"
}
```

### 5. Test in Cursor (30 seconds)

Open Cursor → Chat → Ask: "Write a quick sort function in Python"

---

## Troubleshooting

### Issue: Cursor can't connect to Ollama

**Solution 1**: Check Ollama is listening on network
```bash
sudo netstat -tlnp | grep 11434
# Should show 0.0.0.0:11434
```

**Solution 2**: Check firewall
```bash
sudo ufw status
# Should allow port 11434 from LAN
```

**Solution 3**: Test direct access
```bash
curl http://192.168.1.200:11434/api/tags
```

### Issue: Slow inference speed

**Solution 1**: Check GPU usage
```bash
nvidia-smi
# Should show ollama using GPU
```

**Solution 2**: Use smaller/quantized model
```bash
ollama pull llama3.3:70b-instruct-q4_0  # 4-bit quantization
```

**Solution 3**: Close other GPU applications

### Issue: Out of VRAM

**Solution 1**: Use smaller model
```bash
ollama pull deepseek-r1:14b  # Instead of 32B
```

**Solution 2**: Use quantized model (Q4 instead of Q8)

**Solution 3**: Unload other models
```bash
ollama rm internlm2  # Remove unused models
```

---

## Monitoring & Maintenance

### View Ollama Logs

```bash
journalctl -u ollama -f
```

### Check GPU Usage

```bash
watch -n 1 nvidia-smi
```

### Update Models

```bash
# Check for updates
ollama list

# Pull latest version
ollama pull qwen2.5-coder:32b
```

### Backup Configuration

```bash
# Backup models location
sudo tar -czf ~/ollama-models-backup.tar.gz /usr/share/ollama/.ollama/models

# Backup service config
sudo cp /etc/systemd/system/ollama.service ~/ollama.service.backup
```

---

## Next Steps

1. **Immediate**: Enable Ollama network access (Phase 1)
2. **Short-term**: Test Cursor integration (Phase 3)
3. **Optional**: Add Traefik + Cloudflare routing (Phase 2)
4. **Future**: Try DeepSeek-R1 or QwQ-32B when available in Ollama

---

## Resources

- **Ollama Docs**: https://ollama.ai/
- **Model Library**: https://ollama.ai/library
- **Qwen2.5-Coder**: https://huggingface.co/Qwen/Qwen2.5-Coder-32B-Instruct
- **DeepSeek-R1**: https://huggingface.co/deepseek-ai
- **Cursor Docs**: https://docs.cursor.com/
- **Mistral.rs**: https://github.com/EricLBuehler/mistral.rs

---

## Conclusion

**Recommended Path**:
1. Use **Ollama** (already running)
2. Primary model: **Qwen2.5-Coder-32B** (installed) or **QwQ-32B**
3. Network access: **Expose on 0.0.0.0:11434**
4. LAN: **Direct HTTP access** (http://192.168.1.200:11434)
5. Remote: **Cloudflare Tunnel** → **Traefik** → **Ollama**
6. Cursor: **OpenAI API compatibility** mode

This gives you a Claude 4.5-class local model accessible from anywhere, with full privacy and no API costs.

