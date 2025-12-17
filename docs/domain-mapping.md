# Domain Mapping & Migration Plan

## AWS Account Inventory

| Account | Alias | Account ID | Status | Purpose |
|---------|-------|------------|--------|---------|
| **LEO** | `leo` | 566828793530 | ✅ Active | Personal domains, githired |
| **PIE** | `pie` | 844582634651 | ✅ Active | Production apps |
| **BARGE** | `barge` | - | ✅ Active | Provisions Group (work) |

### Removed Accounts (cleaned from ~/.aws/ and ~/.zshrc)
- ~~UAI~~ (ursulai) - Empty, closed
- ~~SCY~~ (scryar) - Empty, closed
- ~~DRE~~ - Invalid token, closed
- ~~ABYSS~~ - Invalid token, closed
- ~~AWR~~ - Client account, removed from homelab configs
- ~~STEIN~~ - Client account, not included

### Notes
- **Localist** is being transferred to separate SGAI AWS account
- PIE account EC2 instances (localist-*) will be managed by SGAI

## EC2 Instances (Running)

| Account | Instance | Type | Purpose | Action |
|---------|----------|------|---------|--------|
| LEO | i-056440552b6d018b6 | t2.micro | githired | Migrate to K3s |

**Potential Savings**: ~$15-20/month by migrating githired to K3s

## Current Domain Distribution

### AWS Account: LEO (aws-l3o-iam-leo)
| Domain | Zone ID | Purpose | Target |
|--------|---------|---------|--------|
| **omnilemma.com** | Z09855501N1MN7YHRYSGP | AI Meal Planning | Cloudflare |
| **author.works** | Z05113051O0O0QJB9I8TC | Story Platform | Cloudflare |
| **githired.work** | Z0125983ZLN7CEHH4L6K | Job Platform | Cloudflare |
| l3o.xyz | Z1013772113BIU6E11F8M | Personal | Keep R53 |
| leo.xyz | Z02072253MIJBPFU9Q6V0 | Personal | Keep R53 |
| *40+ personal/family domains* | - | Personal sites | Keep R53 |

### AWS Account: PIE (aws-pie-iam-leo)
| Domain | Zone ID | Purpose | Target |
|--------|---------|---------|--------|
| **potluck.pub** | Z06744602W9W1NO99WVGH | Community Dining | Cloudflare |
| **theblink.live** | Z07306541DD1119Y1CZO9 | Live Streaming | Cloudflare |
| **omnilemma.com** | Z07237912PQNZMNTR5QMZ | AI Meal Planning | Cloudflare |
| **hyvapaska.com** | Z08020813QWHGM48NU0Q7 | E-commerce | Cloudflare |
| **americanangel.xyz** | Z07766371J7YL53DSCXBD | NFT Project | Cloudflare |
| leopaska.com | Z0531770ZYV7JQ2RUJZZ | Personal | Cloudflare |
| *25+ other domains* | - | Various | Keep R53 |

### AWS Account: AWR (aws-awr-iam-leo)
| Domain | Zone ID | Purpose | Target |
|--------|---------|---------|--------|
| a-wr.com | Z03136071TUM4TEC0I612 | AuthorWorks short | Cloudflare |
| americanwheelrepair.com | Z01151362RVH40K4MQFIU | Wheel Repair | Keep R53 |
| americanwheelrepairs.com | Z01419331IX6L1F5XSCTH | Wheel Repair | Keep R53 |

### Cloudflare (Current)
| Domain | Zone ID | Status |
|--------|---------|--------|
| **leopaska.xyz** | 7ec42a804e4137fa29452223b5f82d26 | Active - Tunnel configured |

## ⚠️ Redundancy Found

| Issue | Details | Resolution |
|-------|---------|------------|
| **omnilemma.com** duplicate | Exists in BOTH LEO and PIE accounts | Delete one, consolidate to PIE |
| Empty accounts (UAI, SCY) | No resources, still incur potential costs | Close accounts |
| Invalid tokens (DRE, ABYSS) | Credentials expired/invalid | Refresh or close |
| EC2 instances | 3 running instances (~$50-80/mo) | Migrate to K3s, terminate |

---

## Target Architecture

### Domains to Migrate to Cloudflare

**Production Apps (need their own domains):**
| App | Current URL | Target Domain | AWS Account |
|-----|-------------|---------------|-------------|
| Potluck Pub | potluck.leopaska.xyz | **potluck.pub** | PIE |
| TheBlink Live | blink.leopaska.xyz | **theblink.live** | PIE |
| OmniLemma | omni.leopaska.xyz | **omnilemma.com** | PIE/LEO |
| AuthorWorks | authorworks.leopaska.xyz | **author.works** | LEO |
| HyvaPaska | hyva.leopaska.xyz | **hyvapaska.com** | PIE |
| Ursulai | ursulai.leopaska.xyz | **ursulai.com** (TBD) | URSULAI |
| American Enlightenment | ae.leopaska.xyz | **americanangel.xyz** | PIE |
| Localist AI | localist.leopaska.xyz | **localist.ai** (TBD) | LEO |
| Trade Bot | trade.leopaska.xyz | *keep subdomain* | - |

### leopaska.xyz Subdomains (Infrastructure & Docker Services)

**Infrastructure:**
- argocd.leopaska.xyz
- traefik.leopaska.xyz
- grafana.leopaska.xyz
- prometheus.leopaska.xyz
- loki.leopaska.xyz
- uptimekuma.leopaska.xyz

**Docker Services (to migrate to K3s):**
- openwebui.leopaska.xyz
- homeassistant.leopaska.xyz
- jellyfin.leopaska.xyz
- workflow.leopaska.xyz (n8n)
- warden.leopaska.xyz (Vaultwarden)
- minio.leopaska.xyz
- coolify.leopaska.xyz
- pgadmin.leopaska.xyz
- syncthing.leopaska.xyz
- conduit.leopaska.xyz (Matrix)
- element.leopaska.xyz
- rustpad.leopaska.xyz
- rabbitmq.leopaska.xyz
- mcp.leopaska.xyz
- huginn.leopaska.xyz
- postiz.leopaska.xyz
- umami.leopaska.xyz
- rustdesk.leopaska.xyz

---

## K3s Namespace Structure

```
k3s-cluster/
├── ingress-system/          # Traefik, cloudflared
├── cert-manager/            # TLS certificates
├── argocd/                  # GitOps
├── monitoring/              # Prometheus, Grafana, Loki
│
├── production/              # Production apps namespace group
│   ├── potluck/             # potluck.pub
│   ├── blink/               # theblink.live
│   ├── omnilemma/           # omnilemma.com
│   ├── authorworks/         # author.works
│   ├── hyvapaska/           # hyvapaska.com
│   ├── ursulai/             # ursulai.com
│   ├── ae/                  # americanangel.xyz
│   ├── localist/            # localist.leopaska.xyz
│   └── trade/               # trade.leopaska.xyz
│
├── ai/                      # AI services
│   ├── ollama/
│   ├── open-webui/
│   ├── qdrant/
│   └── mcp-server/
│
├── media/                   # Media services
│   ├── jellyfin/
│   └── immich/
│
├── productivity/            # Productivity apps
│   ├── n8n/
│   ├── homeassistant/
│   ├── huginn/
│   └── postiz/
│
├── communication/           # Communication services
│   ├── matrix-conduit/
│   └── element/
│
├── security/                # Security services
│   ├── vaultwarden/
│   ├── authelia/
│   └── rustdesk/
│
├── storage/                 # Storage services
│   ├── minio/
│   └── syncthing/
│
└── databases/               # Shared databases
    ├── postgresql/
    ├── redis/
    └── qdrant/
```

---

## Migration Steps

### Phase 1: Cloudflare DNS Setup (Before K3s Migration)

```bash
# 1. Add production domains to Cloudflare
# Login to Cloudflare Dashboard and add:
# - potluck.pub
# - theblink.live
# - omnilemma.com
# - author.works
# - hyvapaska.com
# - americanangel.xyz

# 2. Export zone IDs to ~/.zshrc
export CLOUDFLARE_ZONE_LEOPASKA="7ec42a804e4137fa29452223b5f82d26"
export CLOUDFLARE_ZONE_POTLUCK="<zone-id-after-adding>"
export CLOUDFLARE_ZONE_BLINK="<zone-id-after-adding>"
export CLOUDFLARE_ZONE_OMNI="<zone-id-after-adding>"
export CLOUDFLARE_ZONE_AUTHOR="<zone-id-after-adding>"
export CLOUDFLARE_ZONE_HYVA="<zone-id-after-adding>"
export CLOUDFLARE_ZONE_AE="<zone-id-after-adding>"

# 3. Create context-switching functions
cf-potluck() { export CLOUDFLARE_ZONE_ID="$CLOUDFLARE_ZONE_POTLUCK"; export CF_DOMAIN="potluck.pub"; }
cf-blink() { export CLOUDFLARE_ZONE_ID="$CLOUDFLARE_ZONE_BLINK"; export CF_DOMAIN="theblink.live"; }
# ... etc
```

### Phase 2: Stop K3d, Install Native K3s

```bash
# 1. Backup current state
kubectl get all -A -o yaml > ~/k3d-backup-$(date +%Y%m%d).yaml
k3d cluster stop alef-homelab

# 2. Install native K3s
sudo ~/git/homelab/scripts/k3s/install-k3s-cluster.sh server-init

# 3. Bootstrap cluster
~/git/homelab/scripts/k3s/bootstrap-cluster.sh
```

### Phase 3: Deploy Services with Proper Domains

ArgoCD will deploy from the config. Each app's Ingress specifies its domain.

---

## Traefik IngressRoute Configuration

### Multi-Domain Ingress Example

```yaml
# Example: potluck.pub app with both domains
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: potluck-pub
  namespace: potluck
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - potluck.pub
        - www.potluck.pub
        - potluck.leopaska.xyz  # Backup subdomain
      secretName: potluck-tls
  rules:
    - host: potluck.pub
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: potluck-frontend
                port:
                  number: 80
    - host: www.potluck.pub
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: potluck-frontend
                port:
                  number: 80
    - host: potluck.leopaska.xyz
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: potluck-frontend
                port:
                  number: 80
```

---

## Cloudflare Tunnel Multi-Domain Config

All domains route through a single Cloudflare Tunnel to Traefik, which handles host-based routing.

```yaml
# /etc/cloudflared/config.yaml
tunnel: homelab-unified
credentials-file: /etc/cloudflared/creds/credentials.json

ingress:
  # All domains go to Traefik
  - hostname: "*.leopaska.xyz"
    service: http://traefik.ingress-system.svc.cluster.local:80
  - hostname: "leopaska.xyz"
    service: http://traefik.ingress-system.svc.cluster.local:80
  - hostname: "*.potluck.pub"
    service: http://traefik.ingress-system.svc.cluster.local:80
  - hostname: "potluck.pub"
    service: http://traefik.ingress-system.svc.cluster.local:80
  - hostname: "*.theblink.live"
    service: http://traefik.ingress-system.svc.cluster.local:80
  - hostname: "theblink.live"
    service: http://traefik.ingress-system.svc.cluster.local:80
  # ... all other production domains
  - service: http_status:404
```

---

## Cost After Migration

| Item | Monthly Cost |
|------|-------------|
| Cloudflare (all domains) | **$0** |
| Route53 (remaining domains) | ~$2-3 |
| GHCR | **$0** |
| K3s | **$0** |
| **Total** | **~$2-3/month** |

---

## Checklist

### Pre-Migration
- [ ] Add all production domains to Cloudflare
- [ ] Record zone IDs in ~/.zshrc
- [ ] Backup K3d state
- [ ] Export Route53 records for reference
- [ ] Update production-apps.yaml with correct domains

### K3s Installation
- [ ] Stop K3d cluster
- [ ] Install native K3s on alef
- [ ] Bootstrap with Traefik, cert-manager, ArgoCD
- [ ] Deploy cloudflared with multi-domain config
- [ ] Verify cluster health

### Service Migration
- [ ] Deploy shared databases (PostgreSQL, Redis)
- [ ] Deploy infrastructure services
- [ ] Deploy AI stack (Ollama, Open WebUI)
- [ ] Deploy production apps
- [ ] Deploy homelab services
- [ ] Verify all domains resolve correctly

### Post-Migration
- [ ] Update nameservers at registrars
- [ ] Delete Route53 hosted zones for migrated domains
- [ ] Update documentation
- [ ] Remove K3d configuration
