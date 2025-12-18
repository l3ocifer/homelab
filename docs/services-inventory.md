# K3S Services Inventory
**Last Updated:** 2025-12-17

## Quick Service URLs

### Monitoring & Analytics
- Grafana: https://grafana.leopaska.xyz (built-in auth)
- Prometheus: https://prometheus.leopaska.xyz (Authelia)
- Loki: https://loki.leopaska.xyz (Authelia)
- Umami: https://umami.leopaska.xyz (Authelia)
- Uptime Kuma: https://uptimekuma.leopaska.xyz (Authelia)
- Traefik: https://traefik.leopaska.xyz (Authelia)

### AI Services
- Open WebUI: https://openwebui.leopaska.xyz (built-in auth)
- LibreChat: https://librechat.leopaska.xyz (built-in auth)
- Ollama: https://ollama.leopaska.xyz
- Proxy Admin: https://proxy-admin.leopaska.xyz (Authelia)

### Productivity
- n8n: https://workflow.leopaska.xyz (built-in auth)
- Home Assistant: https://homeassistant.leopaska.xyz (built-in auth)
- Huginn: https://huginn.leopaska.xyz (built-in auth)
- Postiz: https://postiz.leopaska.xyz (built-in auth)
- Mailhog: https://mailhog.leopaska.xyz (Authelia)

### Storage & Databases
- MinIO: https://minio.leopaska.xyz (Authelia)
- Syncthing: https://syncthing.leopaska.xyz (Authelia)
- WhoDB: https://whodb.leopaska.xyz (Authelia + 2FA)
- RabbitMQ: https://rabbitmq.leopaska.xyz (Authelia)

### Communication
- Element: https://element.leopaska.xyz
- Conduit: https://conduit.leopaska.xyz
- Rustpad: https://rustpad.leopaska.xyz (Authelia)

### Media
- Jellyfin: https://jellyfin.leopaska.xyz (built-in auth)

### Security & Infrastructure
- Authelia: https://authelia.leopaska.xyz
- Vaultwarden: https://warden.leopaska.xyz (built-in auth)
- Logto: https://logto.leopaska.xyz (built-in auth)
- ArgoCD: https://argocd.leopaska.xyz (built-in auth)

## Architecture

Cloudflare DNS → Cloudflare Tunnel → Traefik (NodePort 30080) → IngressRoutes → Services

All services are running in K3S and accessible via their subdomain URLs.
