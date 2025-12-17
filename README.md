# 🏠 Homelab Infrastructure & Services

**Zero-Trust CloudFlare Tunnel + Traefik + Docker + K3Ds Cluster + 45+ Services**

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CloudFlare Tunnel → Zero-Trust Access → Global CDN + DDoS Protection      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────┐  ┌────────────────────────────────────┐
│  Docker Traefik (:80/443/:8080)     │  │  K3s Traefik (NodePort 30080)      │
│  Infrastructure & Dev Services      │  │  Production Applications           │
└─────────────────────────────────────┘  └────────────────────────────────────┘
                    ↓                                      ↓
┌─────────────────────────────────────┐  ┌────────────────────────────────────┐
│  40+ Docker Containers              │  │  K3Ds Cluster (3 nodes)            │
│  PostgreSQL, Redis, Monitoring...   │  │  9 Production Apps + ArgoCD        │
└─────────────────────────────────────┘  └────────────────────────────────────┘
```

---

## 📋 Docker Services (Infrastructure)

### Core Infrastructure
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **Traefik** | 8080 | https://traefik.leopaska.xyz | ✅ Running |
| **PostgreSQL** | 5432 | Internal Only | ✅ Running |
| **Redis** | 6379 | Internal Only | ✅ Running |
| **Authelia** | 9091 | https://authelia.leopaska.xyz | ✅ Running |

### AI/ML Services
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **OpenWebUI** | 3333 | https://openwebui.leopaska.xyz | ✅ Running |
| **Ollama Proxy** | 8888 | https://proxy-admin.leopaska.xyz | ✅ Running |
| **Qdrant** | 6333/6334 | Internal Only | ✅ Running |
| **MCP Modules Rust** | 8890 | https://mcp.leopaska.xyz | ✅ Running |

### Monitoring & Observability
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **Grafana** | 3000 | https://grafana.leopaska.xyz | ✅ Running |
| **Prometheus** | 9090 | https://prometheus.leopaska.xyz | ✅ Running |
| **Loki** | 3100 | https://loki.leopaska.xyz | ✅ Running |
| **Uptime Kuma** | 3001 | https://uptimekuma.leopaska.xyz | ✅ Running |
| **Umami** | 3006 | https://umami.leopaska.xyz | ✅ Running |
| **Vector** | - | Internal Only | ✅ Running |
| **Node Exporter** | 9100 | Internal Only | ✅ Running |

### Productivity & Automation
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **n8n** | 5678 | https://workflow.leopaska.xyz | ✅ Running |
| **Coolify** | 8000 | https://coolify.leopaska.xyz | ✅ Running |
| **HomeAssistant** | 8123 | https://homeassistant.leopaska.xyz | ✅ Running |
| **Huginn** | 3010 | https://huginn.leopaska.xyz | ✅ Running |
| **Postiz** | 3000 | https://postiz.leopaska.xyz | ⚠️ Restarting |

### Storage & Data
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **MinIO** | 9000/9001 | https://minio.leopaska.xyz | ✅ Running |
| **Syncthing** | 8384 | https://syncthing.leopaska.xyz | ✅ Running |
| **Spacedrive** | 8081 | https://spacedrive.leopaska.xyz | ✅ Running |

### Communication
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **Conduit** | 6167 | https://conduit.leopaska.xyz | ✅ Running |
| **Element** | 8099 | https://element.leopaska.xyz | ✅ Running |
| **RustPad** | 3030 | https://rustpad.leopaska.xyz | ✅ Running |
| **MailHog** | 8025 | https://mailhog.leopaska.xyz | ✅ Running |

### Security & Access
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **Vaultwarden** | 8085 | https://warden.leopaska.xyz | ✅ Running |
| **RustDesk HBBS** | 21118 | https://rustdesk.leopaska.xyz | ✅ Running |
| **RustDesk HBBR** | 21117 | Internal Only | ✅ Running |

### Database Tools
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **PgAdmin** | 5050 | https://pgadmin.leopaska.xyz | ✅ Running |
| **Adminer** | 8084 | https://adminer.leopaska.xyz | ✅ Running |
| **WhoDB** | 8082 | https://whodb.leopaska.xyz | ✅ Running |

### Media
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **Jellyfin** | 8096 | https://jellyfin.leopaska.xyz | ✅ Running |

### Message Queue
| Service | Port | External URL | Status |
|---------|------|--------------|--------|
| **RabbitMQ** | 5672/15672 | https://rabbitmq.leopaska.xyz | ✅ Running |

---

## 🚀 K3Ds Cluster (Production Apps)

### Cluster Status
| Node | Role | Status |
|------|------|--------|
| k3d-alef-homelab-server-0 | Control Plane | ✅ Ready |
| k3d-alef-homelab-agent-0 | Worker | ✅ Ready |
| k3d-alef-homelab-agent-1 | Worker | ✅ Ready |

### Production Applications
| App | External URL | Status |
|-----|--------------|--------|
| **Localist AI** | https://localist.leopaska.xyz | ✅ Running |
| **Potluck Pub** | https://potluck.leopaska.xyz | ⚠️ Backend Issues |
| **TheBlink Live** | https://blink.leopaska.xyz | ✅ Running |
| **Trade Bot** | https://trade.leopaska.xyz | ⚠️ CrashLoopBackOff |
| **HyvaPaska** | https://hyva.leopaska.xyz | ✅ Running |
| **Ursulai** | https://ursulai.leopaska.xyz | ✅ Running |
| **OmniLemma** | https://omni.leopaska.xyz | ✅ Running |
| **American Enlightenment** | https://ae.leopaska.xyz | ✅ Running |
| **AuthorWorks** | https://authorworks.leopaska.xyz | ✅ Running |

### K3s Platform Services
| Service | Purpose | Status |
|---------|---------|--------|
| **ArgoCD** | GitOps Deployments | ⚠️ Partial |
| **Cert-Manager** | TLS Certificates | ✅ Running |
| **Traefik (K3s)** | Ingress Controller | ✅ Running |
| **SpinKube** | Serverless Functions | ✅ Running |

---

This homelab provides a production-ready, secure, and scalable infrastructure using CloudFlare tunnels for external access and Traefik for internal routing. All services are containerized and follow zero-trust security principles.

## 🚀 Quick Start

```bash
# Deploy all services
cd services && ./deploy-all.sh all

# Start CloudFlare tunnel
sudo systemctl start alef-cloudflare-tunnel.service

# Access services via tunnel (once DNS propagates)
# https://traefik.leopaska.xyz
# https://grafana.leopaska.xyz
# https://workflow.leopaska.xyz
```

## 🌐 Service Access

### **External Access (via CloudFlare Tunnel)**
All services accessible at `https://service.leopaska.xyz`:

#### Docker Services
| Service | URL | Purpose |
|---------|-----|---------|
| **Traefik** | `traefik.leopaska.xyz` | Reverse proxy dashboard |
| **Grafana** | `grafana.leopaska.xyz` | Monitoring dashboards |
| **Prometheus** | `prometheus.leopaska.xyz` | Metrics collection |
| **N8N** | `workflow.leopaska.xyz` | Workflow automation |
| **OpenWebUI** | `openwebui.leopaska.xyz` | AI chat interface |
| **Ollama Proxy Admin** | `proxy-admin.leopaska.xyz` | API key management |
| **Ollama Proxy API** | `proxy-api.leopaska.xyz` | Authenticated Ollama access |
| **HomeAssistant** | `homeassistant.leopaska.xyz` | Home automation |
| **Vaultwarden** | `warden.leopaska.xyz` | Password manager |
| **Syncthing** | `syncthing.leopaska.xyz` | File synchronization |
| **MinIO** | `minio.leopaska.xyz` | Object storage console |
| **Coolify** | `coolify.leopaska.xyz` | Deployment platform |
| **RustPad** | `rustpad.leopaska.xyz` | Collaborative editor |
| **Huginn** | `huginn.leopaska.xyz` | Event automation |
| **Postiz** | `postiz.leopaska.xyz` | Social media management |
| **WhoDB** | `whodb.leopaska.xyz` | Database explorer |
| **UptimeKuma** | `uptimekuma.leopaska.xyz` | Service monitoring |
| **Umami** | `umami.leopaska.xyz` | Privacy-focused analytics |
| **Spacedrive** | `spacedrive.leopaska.xyz` | File management |
| **Element** | `element.leopaska.xyz` | Matrix chat client |
| **Conduit** | `conduit.leopaska.xyz` | Matrix server |
| **Authelia** | `authelia.leopaska.xyz` | Authentication service |
| **PgAdmin** | `pgadmin.leopaska.xyz` | PostgreSQL admin |
| **Adminer** | `adminer.leopaska.xyz` | Lightweight DB admin |
| **RabbitMQ** | `rabbitmq.leopaska.xyz` | Message queue UI |
| **MailHog** | `mailhog.leopaska.xyz` | Email testing |
| **Jellyfin** | `jellyfin.leopaska.xyz` | Media server |
| **RustDesk** | `rustdesk.leopaska.xyz` | Remote desktop |
| **MCP Server** | `mcp.leopaska.xyz` | AI tool server |

#### K3s Production Apps
| App | URL | Purpose |
|-----|-----|---------|
| **Localist AI** | `localist.leopaska.xyz` | Local discovery AI |
| **Potluck Pub** | `potluck.leopaska.xyz` | Community events platform |
| **TheBlink Live** | `blink.leopaska.xyz` | Live streaming platform |
| **Trade Bot** | `trade.leopaska.xyz` | Voice-controlled trading |
| **HyvaPaska** | `hyva.leopaska.xyz` | Personal platform |
| **Ursulai** | `ursulai.leopaska.xyz` | AI assistant |
| **OmniLemma** | `omni.leopaska.xyz` | Knowledge platform |
| **American Enlightenment** | `ae.leopaska.xyz` | Educational content |
| **AuthorWorks** | `authorworks.leopaska.xyz` | AI story creation |
| **ArgoCD** | `argocd.leopaska.xyz` | GitOps dashboard |

### **Internal Access (LAN)**
Services also accessible via:
- `http://service.localhost` 
- `http://192.168.1.200:port`

## 🔒 Security Architecture (Zero-Trust)

### **Multi-Layer Security**
1. **CloudFlare Edge Protection**
   - DDoS protection, WAF, Bot Fight Mode
   - Global CDN with edge caching
   - SSL/TLS termination

2. **Encrypted Tunnel**
   - QUIC/HTTP2 encrypted connection
   - No public IP exposure
   - End-to-end encryption

3. **Traefik Security Middleware**
   - Rate limiting (Admin: 20 req/min, API: 50 req/min)
   - Security headers (CSP, HSTS, X-Frame-Options)
   - Conditional authentication
   - IP whitelisting for internal access

4. **Service-Level Security**
   - Application authentication
   - Database encryption
   - No credential storage in git

### **Security Headers Applied**
```yaml
Content-Security-Policy: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'..."
Strict-Transport-Security: "max-age=31536000; includeSubDomains; preload"
X-Frame-Options: "SAMEORIGIN"
X-Content-Type-Options: "nosniff"
Referrer-Policy: "strict-origin-when-cross-origin"
Permissions-Policy: "geolocation=(), microphone=(), camera=()..."
```

## 🏗️ Architecture Overview

### **Network Flow**
```
Internet → CloudFlare → Encrypted Tunnel → Traefik (localhost:80/443) → Services
```

### **Port Strategy**
- **No public ports** except Traefik 80/443/8080 (internal only)
- **CloudFlare tunnel** handles all external access
- **Traefik** routes internal and tunnel traffic
- **Service isolation** via Docker networks

### **Service Categories**

| Category | Services | Security Level |
|----------|----------|----------------|
| **Admin** | Traefik, Grafana, Prometheus, Loki, Uptime Kuma | Admin auth + rate limiting |
| **Productivity** | N8N, Coolify, HomeAssistant, Huginn, Postiz | API rate limiting |
| **AI/ML** | OpenWebUI, Ollama Proxy, Qdrant, MCP Server, Umami | API rate limiting |
| **Communication** | Element, Conduit, RustPad, MailHog | API rate limiting |
| **Storage** | MinIO, Syncthing, Spacedrive | API rate limiting |
| **Security** | Authelia, Vaultwarden, RustDesk | Special handling |
| **Database** | PostgreSQL, Redis, PgAdmin, Adminer, WhoDB | Internal/Admin only |
| **Infrastructure** | Vector, Node Exporter, RabbitMQ | Internal only |
| **Media** | Jellyfin | API rate limiting |
| **K3s Apps** | Localist, Potluck, Blink, Trade, Hyva, Ursulai, Omni, AE, AuthorWorks | K3s Ingress |

## 🛠️ Adding New Services

### **Step-by-Step Process**

1. **Add to docker-compose.yml**
```yaml
  new-service:
    image: service/image:latest
    container_name: new-service-${DOMAIN_BASE}
    restart: unless-stopped
    ports:
      - "PORT:PORT"  # Internal port only
    environment:
      - SERVICE_CONFIG=value
    networks:
      - llm_network
    labels:
      - "traefik.enable=true"
      # Unified access (tunnel + internal)
      - "traefik.http.routers.new-service.rule=Host(`newservice.${DOMAIN}`) || HostRegexp(`{host:(newservice.localhost|newservice.lan|192\\.168\\..*|172\\..*|10\\..*)}`)"
      - "traefik.http.routers.new-service.entrypoints=web,websecure"
      - "traefik.http.services.new-service.loadbalancer.server.port=PORT"
      - "traefik.http.routers.new-service.service=new-service"
      - "traefik.http.routers.new-service.middlewares=api-rate-limit@file,security@file"
```

2. **Add to CloudFlare tunnel template**
```yaml
# Add to /home/l3o/git/homelab/cloudflare-tunnel/config.template.yml
  - hostname: newservice.{{DOMAIN}}
    service: http://localhost:80
    originRequest:
      httpHostHeader: newservice.{{DOMAIN}}
```

3. **Create DNS record**
```bash
cloudflared tunnel route dns homelab-tunnel newservice.leopaska.xyz
```

4. **Deploy and test**
```bash
# Regenerate tunnel config
cd /home/l3o/git/homelab/cloudflare-tunnel && ./generate-config.sh

# Restart services
cd /home/l3o/git/homelab/services
docker-compose up -d new-service
sudo systemctl restart alef-cloudflare-tunnel.service

# Test access
curl -I http://localhost:PORT  # Internal test
curl -I https://newservice.leopaska.xyz  # External test (after DNS propagation)
```

## 🔧 Configuration Management

### **Environment Variables (.env)**
```bash
# Core settings
DOMAIN=leopaska.xyz
DOMAIN_BASE=leopaska
LOCAL_DOMAIN=localhost

# Security
POSTGRES_PASSWORD=secure_password
REDIS_PASSWORD=secure_password
TRAEFIK_AUTH=admin:hashed_password

# Service-specific
GRAFANA_PASSWORD=admin_password
COOLIFY_APP_KEY=app_key
```

### **Traefik Configuration**
- **Dynamic routing** via `${DOMAIN}` variable
- **Unified routers** - No local/remote duplication
- **Security middleware** - Rate limiting, headers, auth
- **Service discovery** - Automatic Docker label detection

### **CloudFlare Tunnel**
- **Template-based config** - Dynamic domain support
- **Automatic generation** - Updates on service restart
- **Health monitoring** - 4 redundant connections
- **Systemd integration** - Auto-start, logging, restart

## 🔍 Monitoring & Observability

### **Health Checks**
```bash
# Service status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Tunnel status
sudo systemctl status alef-cloudflare-tunnel.service

# Service logs
docker-compose logs -f service-name

# Tunnel logs
journalctl -u alef-cloudflare-tunnel.service -f
```

### **Monitoring Stack**
- **Prometheus** - Metrics collection
- **Grafana** - Visualization dashboards
- **Loki** - Log aggregation
- **Uptime Kuma** - Service availability monitoring
- **Node Exporter** - System metrics

## 🚨 Troubleshooting

### **Common Issues**

#### **DNS Not Resolving**
```bash
# Check nameserver propagation
dig NS leopaska.xyz

# Check CloudFlare DNS
dig traefik.leopaska.xyz @1.1.1.1

# Check tunnel DNS records
curl -X GET "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

#### **Services Not Accessible**
```bash
# Check Traefik routing
curl -H "Host: service.leopaska.xyz" http://localhost:80

# Check service health
docker-compose ps service-name

# Check Traefik logs
docker-compose logs traefik
```

#### **Tunnel Issues**
```bash
# Restart tunnel
sudo systemctl restart alef-cloudflare-tunnel.service

# Check tunnel connectivity
cloudflared tunnel --config config.yml ingress validate

# Test tunnel routing
cloudflared tunnel --config config.yml ingress url https://traefik.leopaska.xyz
```

## 📋 Service Dependencies

### **Database Services**
- **PostgreSQL** - Shared by Grafana, Authelia, N8N, Vaultwarden, Coolify, Huginn, Umami, Postiz, Ollama Proxy, etc.
- **Redis** - Session storage, caching, rate limiting
- **Qdrant** - Vector database for AI/ML embeddings
- **Automatic DB creation** - Init scripts create required databases

### **Docker ↔ K3s Integration**
- K3s apps access Docker services via `external-postgres.default.svc.cluster.local`
- K3d nodes connected to `llm_network` for direct container access
- External services defined in `k3s-external-services.yaml`

### **Authentication Flow**
- **Authelia** - SSO provider for Docker services
- **Conditional auth** - External vs internal access
- **Service integration** - Apps can use Authelia headers

### **Monitoring Integration**
- **All services** export metrics to Prometheus
- **Grafana dashboards** for each service category
- **Loki logging** - Centralized log aggregation via Vector
- **Uptime Kuma** - Service availability monitoring
- **Health checks** - Docker + custom health endpoints

### **Message Queue**
- **RabbitMQ** - Async processing for production apps
- Available to K3s apps via `external-rabbitmq.default.svc.cluster.local`

## 🔄 Maintenance

### **Regular Tasks**
```bash
# Update all services
docker-compose pull && docker-compose up -d

# Clean up unused resources
docker system prune -a

# Backup databases
./scripts/backup-all.sh

# Check security updates
./scripts/security-audit.sh
```

### **Security Audits**
```bash
# Check exposed ports
netstat -tulpn | grep LISTEN

# Verify tunnel connections
sudo systemctl status alef-cloudflare-tunnel.service

# Check Traefik security headers
curl -I https://traefik.leopaska.xyz
```

## 📁 Directory Structure

This repository is organized as a monorepo with git submodules for major components.

```
homelab/                                # Git monorepo
├── README.md                           # This comprehensive guide
├── .gitmodules                         # Submodule definitions
│
├── docs/                               # All documentation (lowercase-dashes)
│   ├── reorganization-plan.md          # Architecture migration plan
│   ├── capacity-and-health-report.md   # System health report
│   ├── ollama-*.md                     # Ollama setup guides
│   └── ...
│
├── scripts/                            # Homelab-wide utility scripts
│   └── init-git-repo.sh                # Repository initialization
│
├── alef/                               # [SUBMODULE] K3s cluster & ArgoCD
│   ├── argocd/                         # GitOps configuration
│   │   ├── applications/               # ArgoCD app definitions
│   │   └── root-app.yaml               # App of Apps pattern
│   ├── config/k3s/                     # K3d cluster configuration
│   ├── terraform/                      # Infrastructure as Code
│   ├── scripts/                        # Cluster management scripts
│   └── services/                       # Systemd service files
│
├── services/                           # [SUBMODULE] Docker services & Ansible
│   ├── docker-compose.yml              # All Docker service definitions
│   ├── cloudflare-tunnel/              # CloudFlare tunnel config
│   ├── traefik/                        # Traefik dynamic config
│   ├── ansible/                        # Ansible playbooks & roles
│   └── [service-configs]/              # Individual service configs
│
├── mcp-modules-rust/                   # [SUBMODULE] MCP server (Rust)
├── claude-configs/                     # [SUBMODULE] Claude Code config
├── cursor-configs/                     # [SUBMODULE] Cursor IDE config
└── thebeast/                           # [SUBMODULE] Multi-machine scripts
```

### Cloning with Submodules

```bash
# Clone with all submodules
git clone --recurse-submodules git@github.com:l3ocifer/homelab.git

# Or, after cloning, initialize submodules
git submodule update --init --recursive
```

## 🎯 Best Practices Implemented

### **Security**
- ✅ Zero public IP exposure
- ✅ End-to-end encryption (CloudFlare → Tunnel → Traefik → Service)
- ✅ Rate limiting (per-service, per-IP)
- ✅ Security headers (CSP, HSTS, etc.)
- ✅ Conditional authentication
- ✅ Network isolation

### **Reliability**
- ✅ Health checks for all services
- ✅ Automatic restarts
- ✅ Database redundancy
- ✅ Monitoring & alerting
- ✅ Backup automation

### **Maintainability**
- ✅ Dynamic configuration (no hardcoded domains)
- ✅ Template-based tunnel config
- ✅ Consistent naming patterns
- ✅ Comprehensive documentation
- ✅ Easy service addition process

### **Performance**
- ✅ Global CDN via CloudFlare
- ✅ HTTP/2 and QUIC protocols
- ✅ Resource limits and reservations
- ✅ Optimized Docker networking
- ✅ Prometheus metrics collection

---

## 🔗 Quick Access (Internal)

### Docker Services
- **Traefik Dashboard**: http://localhost:8080
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090
- **N8N**: http://localhost:5678
- **OpenWebUI**: http://localhost:3333
- **PgAdmin**: http://localhost:5050
- **Uptime Kuma**: http://localhost:3001

### K3s Services
- **K3s Traefik**: http://localhost:30808
- **ArgoCD**: http://localhost:30080 (Host: argocd.leopaska.xyz)

## 🔗 Quick Access (External)

### Docker Services
- **Traefik Dashboard**: https://traefik.leopaska.xyz
- **Grafana**: https://grafana.leopaska.xyz
- **Prometheus**: https://prometheus.leopaska.xyz
- **N8N**: https://workflow.leopaska.xyz
- **OpenWebUI**: https://openwebui.leopaska.xyz
- **HomeAssistant**: https://homeassistant.leopaska.xyz

### K3s Production Apps
- **Localist AI**: https://localist.leopaska.xyz
- **Potluck Pub**: https://potluck.leopaska.xyz
- **ArgoCD**: https://argocd.leopaska.xyz

---

## 📊 Resource Utilization

| Resource | Current | Available | Status |
|----------|---------|-----------|--------|
| **Memory** | ~13GB / 54GB | 41GB (76%) | ✅ Excellent |
| **Prod SSD** | 323GB / 3.7TB | 3.2TB (90%) | ✅ Excellent |
| **Docker Containers** | 40 running | - | ✅ Healthy |
| **K3s Nodes** | 3 Ready | - | ✅ Healthy |
| **K3s Pods** | ~25 Running | - | ⚠️ Some issues |

---

**Cost**: ~$0.50/month (Route53 DNS only)  
**Security**: Maximum (Zero public IP exposure)  
**Performance**: Global CDN + DDoS protection  
**Maintenance**: Automated updates and monitoring  

**Last Updated**: November 2025  
**Maintained By**: Leo Paska