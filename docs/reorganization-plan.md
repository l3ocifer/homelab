# 🏗️ Homelab Reorganization Plan
## Cost-Optimized K3S + ArgoCD + Traefik + Cloudflare Architecture

---

## 📊 Current State Analysis

### Infrastructure Inventory

| Component | Current State | Target State |
|-----------|---------------|--------------|
| **Main Server (alef)** | 55GB RAM, 3TB storage, Docker + K3d | K3s control-plane + worker |
| **Legion Cluster** | 20+ Raspberry Pi nodes (unused for K8s) | K3s worker nodes |
| **Container Orchestration** | K3d (Docker-based) | K3s (native) |
| **DNS** | Route53 + Cloudflare hybrid | Cloudflare primary |
| **GitOps** | ArgoCD (partial) | ArgoCD (full automation) |
| **Domains** | leopaska.xyz + others via AWS accounts | Cloudflare-managed |

### AWS Accounts & Domains

| Alias | AWS Profile | Likely Domain | Purpose |
|-------|-------------|---------------|---------|
| `leo` | aws-l3o-iam-leo | leopaska.xyz | Personal/Homelab |
| `pie` | aws-pie-iam-leo | TBD | Production Apps |
| `uai` | aws-ursulai-iam-leo | ursulai.com | AI Product |
| `awr` | aws-awr-iam-leo | authorworks.* | Story Platform |
| `dre` | aws-dre-iam-leo | TBD | Unknown |
| `scy` | aws-scryar-iam-leo | scryar.* | Unknown |
| `abyss` | aws-abyss-iam-leothelion | TBD | Unknown |
| `stein` | aws-stein-iam-L3o | TBD | Unknown |
| `barge` | aws-pg-barge-* | provisionsgroup.* | Business |

---

## 🎯 Target Architecture

### Cost Breakdown (Monthly)

| Item | Provider | Cost | Notes |
|------|----------|------|-------|
| DNS (Primary) | Cloudflare | **$0** | Free tier |
| DNS (AWS delegation) | Route 53 | ~$0.50 | Per hosted zone |
| CDN/DDoS/WAF | Cloudflare | **$0** | Free tier |
| Tunnel | Cloudflare | **$0** | Free tier |
| Container Registry | GHCR | **$0** | Free |
| Kubernetes | K3s | **$0** | Self-hosted |
| **Total Cloud** | | **~$0.50-1/month** | |

### Network Flow

```
Internet → Cloudflare (DNS + CDN + WAF + Tunnel)
    ↓
Cloudflared (2 replicas in K3s)
    ↓
Traefik Ingress Controller
    ↓
┌─────────────────┬─────────────────┬─────────────────┐
│   production    │    services     │       ai        │
│   namespace     │    namespace    │   namespace     │
│                 │                 │                 │
│ • Potluck       │ • Jellyfin      │ • Ollama        │
│ • AuthorWorks   │ • Nextcloud     │ • Open WebUI    │
│ • Localist      │ • Vaultwarden   │ • Qdrant        │
│ • Ursulai       │ • HomeAssistant │                 │
│ • 10+ apps      │ • 30+ services  │                 │
└─────────────────┴─────────────────┴─────────────────┘
```

---

## 📋 Migration Phases

### Phase 1: Foundation (Day 1-2)

#### 1.1 Cloudflare CLI Setup
Add Cloudflare CLI functions to match AWS patterns:

```bash
# Add to ~/.zshrc
export CLOUDFLARE_ZONE_LEOPASKA="7ec42a804e4137fa29452223b5f82d26"

cf() {
    export CLOUDFLARE_ZONE_ID="$CLOUDFLARE_ZONE_LEOPASKA"
    export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN_LEOPASKA}"
    echo "Cloudflare context: leopaska.xyz"
}

cf-leo() { cf; }  # Alias for consistency
cf-pie() {
    export CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_PIE}"
    export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN_PIE}"
    echo "Cloudflare context: [PIE domain]"
}

# Cloudflare helper functions
cf-dns-list() {
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" | jq '.result[] | {name, type, content}'
}

cf-tunnel-status() {
    cloudflared tunnel list
}
```

#### 1.2 DNS Strategy Decision
**Recommended: Option A (Cloudflare Primary)**

```
Cloudflare DNS (leopaska.xyz, ursulai.com, etc.)
├── *.leopaska.xyz          → Tunnel → Homelab
├── *.ursulai.com           → Tunnel → Homelab
├── *.authorworks.*         → Tunnel → Homelab
│
└── NS aws.leopaska.xyz     → Route 53 (AWS-specific only)
    └── rds.aws.leopaska.xyz → RDS endpoints
    └── vpc.aws.leopaska.xyz → VPC resources
```

### Phase 2: K3s Native Migration (Day 2-3)

#### 2.1 Convert K3d to K3s

Current K3d is containerized Kubernetes. For production reliability, migrate to native K3s.

**Option A: In-place migration on alef (Recommended)**
```bash
# 1. Export all K3d workloads
kubectl get all -A -o yaml > k3d-backup.yaml

# 2. Stop K3d cluster
k3d cluster stop alef-homelab

# 3. Install native K3s
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --tls-san 192.168.1.200 \
  --tls-san k3s.leopaska.xyz \
  --node-label node-role.kubernetes.io/control-plane=true

# 4. Get join token for workers
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Option B: Fresh cluster with Legion nodes**
```bash
# On legion001-005 (worker nodes)
curl -sfL https://get.k3s.io | sh -s - agent \
  --server https://192.168.1.200:6443 \
  --token YOUR_TOKEN \
  --node-label node-type=arm \
  --node-label node-role=worker
```

#### 2.2 Node Configuration

| Node | Role | IP | Labels |
|------|------|-----|--------|
| alef | control-plane, worker | 192.168.1.200 | gpu=available, zone=primary |
| legion001-005 | worker | 192.168.1.201-205 | arch=arm64, zone=dns |
| legion006-010 | worker | 192.168.1.206-210 | arch=arm64, zone=monitoring |
| legion011-014 | worker | 192.168.1.211-214 | arch=arm64, zone=storage |
| legion015-016,019 | worker | 192.168.1.215-219 | arch=arm64, zone=edge |

### Phase 3: GitOps Repository Restructure (Day 3-4)

#### 3.1 New Repository Structure

```
homelab-gitops/                    # Main GitOps repo
├── README.md
├── argocd/
│   ├── app-of-apps.yaml          # Root application
│   └── apps/
│       ├── infrastructure.yaml    # Core infra
│       ├── production.yaml        # Production apps
│       ├── staging.yaml           # Staging apps
│       ├── services.yaml          # Homelab services
│       ├── ai.yaml                # AI/LLM stack
│       └── monitoring.yaml        # Observability
│
├── infrastructure/
│   ├── base/
│   │   ├── traefik/
│   │   ├── cloudflared/
│   │   ├── cert-manager/
│   │   ├── sealed-secrets/
│   │   └── external-secrets/
│   └── overlays/
│       ├── production/
│       └── staging/
│
├── apps/
│   ├── production/
│   │   ├── localist-ai/
│   │   ├── potluck-pub/
│   │   ├── authorworks/
│   │   ├── ursulai/
│   │   ├── theblink/
│   │   ├── omnilemma/
│   │   ├── american-enlightenment/
│   │   ├── hyvapaska/
│   │   └── trade-bot/
│   └── staging/
│       └── [mirrors of production with lower resources]
│
├── services/
│   ├── media/
│   │   ├── jellyfin/
│   │   └── immich/
│   ├── productivity/
│   │   ├── n8n/
│   │   ├── nextcloud/
│   │   ├── paperless/
│   │   └── homeassistant/
│   ├── communication/
│   │   ├── matrix/
│   │   └── element/
│   ├── security/
│   │   ├── vaultwarden/
│   │   ├── authelia/
│   │   └── rustdesk/
│   └── databases/
│       ├── postgresql/
│       ├── redis/
│       └── qdrant/
│
├── ai/
│   ├── ollama/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml
│   │   └── init-models-job.yaml
│   ├── open-webui/
│   ├── qdrant/
│   └── mcp-server/
│
└── monitoring/
    ├── prometheus/
    ├── grafana/
    ├── loki/
    └── uptime-kuma/
```

### Phase 4: Cloudflare Tunnel Consolidation (Day 4)

#### 4.1 Multi-Domain Tunnel Configuration

```yaml
# cloudflared-config.yaml
tunnel: homelab-unified
credentials-file: /etc/cloudflared/creds/credentials.json
metrics: 0.0.0.0:2000
no-autoupdate: true

ingress:
  # === DOMAIN: leopaska.xyz ===
  - hostname: "*.leopaska.xyz"
    service: http://traefik.ingress-system.svc.cluster.local:80
  
  # === DOMAIN: ursulai.com ===
  - hostname: "*.ursulai.com"
    service: http://traefik.ingress-system.svc.cluster.local:80
  
  # === DOMAIN: authorworks.* ===
  - hostname: "*.authorworks.io"
    service: http://traefik.ingress-system.svc.cluster.local:80
  
  # === SSH Access (Zero Trust) ===
  - hostname: ssh.leopaska.xyz
    service: ssh://localhost:22
  
  # Catch-all
  - service: http_status:404
```

#### 4.2 Deploy cloudflared in K3s

```yaml
# cloudflared/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: ingress-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: cloudflared
              topologyKey: kubernetes.io/hostname
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          args: ["tunnel", "--config", "/etc/cloudflared/config/config.yaml", "run"]
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared/config
            - name: creds
              mountPath: /etc/cloudflared/creds
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
```

### Phase 5: Service Migration (Week 1-2)

#### 5.1 Migration Order

| Priority | Category | Services | Strategy |
|----------|----------|----------|----------|
| 1 | Infrastructure | Traefik, cert-manager, sealed-secrets | Deploy first |
| 2 | Databases | PostgreSQL, Redis, Qdrant | Migrate with data |
| 3 | Auth | Authelia, Logto | Configure SSO |
| 4 | Stateless Apps | Production apps (9 apps) | Parallel deploy |
| 5 | Stateful Services | Jellyfin, Nextcloud, Vaultwarden | Careful migration |
| 6 | AI Stack | Ollama, Open WebUI, MCP | GPU scheduling |
| 7 | Monitoring | Prometheus, Grafana, Loki | Last (needs everything) |

#### 5.2 Data Migration Strategy

```bash
# 1. Backup Docker volumes
docker run --rm -v jellyfin_config:/data -v $(pwd):/backup alpine \
  tar czf /backup/jellyfin-config.tar.gz /data

# 2. Create K3s PVCs
kubectl apply -f services/media/jellyfin/pvc.yaml

# 3. Restore data to K3s
kubectl run restore --rm -it --image=alpine \
  --overrides='{"spec":{"containers":[{"name":"restore","image":"alpine","volumeMounts":[{"name":"data","mountPath":"/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"jellyfin-config"}}]}}' \
  -- tar xzf /backup/jellyfin-config.tar.gz -C /
```

---

## 🔧 Implementation Scripts

### Script 1: Cloudflare Functions (add to ~/.zshrc)

See: `scripts/cloudflare-functions.sh`

### Script 2: K3s Installation

See: `scripts/install-k3s.sh`

### Script 3: DNS Migration

See: `scripts/migrate-dns-to-cloudflare.sh`

### Script 4: GitOps Bootstrap

See: `scripts/bootstrap-argocd.sh`

---

## 📅 Timeline

| Day | Phase | Tasks |
|-----|-------|-------|
| 1 | Foundation | CF CLI setup, DNS strategy decision |
| 2 | K3s | Install native K3s, join Legion workers |
| 3 | GitOps | Create repo structure, bootstrap ArgoCD |
| 4 | Tunnel | Multi-domain tunnel in K3s |
| 5-7 | Migration | Core services (DBs, auth) |
| 8-10 | Migration | Production apps |
| 11-12 | Migration | Stateful services |
| 13-14 | AI/Monitoring | Ollama, monitoring stack |

---

## ✅ Success Criteria

- [ ] All 40+ services running in K3s
- [ ] All 9 production apps accessible via Cloudflare Tunnel
- [ ] GitOps: ArgoCD auto-syncing all changes
- [ ] DNS: Cloudflare primary with Route53 delegation
- [ ] Cost: <$5/month cloud spend
- [ ] Uptime: 99.9% via HA cloudflared + K3s
- [ ] CLI: `cf-leo`, `cf-pie` functions working

---

## 🔗 Related Documents

- [Current README](./README.md)
- [Cloudflare Tunnel Setup](./services/cloudflare-tunnel/README.md)
- [K3s External Services](./alef/k3s-external-services.yaml)
- [ArgoCD Applications](./alef/argocd/applications/)
