#!/bin/bash
# Complete K3d to K3s Migration Script
# =====================================
# This script handles the full migration from K3d to native K3s
#
# Prerequisites:
#   - K3d currently running
#   - Docker services running
#   - Cloudflare tunnel configured
#
# Usage:
#   ./migrate-k3d-to-k3s.sh backup    # Step 1: Backup everything
#   ./migrate-k3d-to-k3s.sh stop      # Step 2: Stop K3d
#   ./migrate-k3d-to-k3s.sh install   # Step 3: Install K3s
#   ./migrate-k3d-to-k3s.sh bootstrap # Step 4: Bootstrap cluster
#   ./migrate-k3d-to-k3s.sh deploy    # Step 5: Deploy applications
#   ./migrate-k3d-to-k3s.sh verify    # Step 6: Verify migration
#   ./migrate-k3d-to-k3s.sh full      # Run all steps

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="/home/l3o/git/homelab"
BACKUP_DIR="/home/l3o/backups/k3d-migration-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[MIGRATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Step 1: Backup everything
backup() {
    log "Step 1: Backing up current state..."
    mkdir -p "$BACKUP_DIR"

    # Backup K3d cluster state
    if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null; then
        log "Backing up Kubernetes resources..."
        kubectl get all -A -o yaml > "$BACKUP_DIR/all-resources.yaml"
        kubectl get pv -o yaml > "$BACKUP_DIR/persistent-volumes.yaml" 2>/dev/null || true
        kubectl get pvc -A -o yaml > "$BACKUP_DIR/persistent-volume-claims.yaml" 2>/dev/null || true
        kubectl get secrets -A -o yaml > "$BACKUP_DIR/secrets.yaml" 2>/dev/null || true
        kubectl get configmaps -A -o yaml > "$BACKUP_DIR/configmaps.yaml" 2>/dev/null || true
        kubectl get ingress -A -o yaml > "$BACKUP_DIR/ingresses.yaml" 2>/dev/null || true
    fi

    # Backup Docker volumes
    log "Backing up critical Docker volumes..."
    VOLUMES_TO_BACKUP=(
        "homeassistant_config"
        "vaultwarden_data"
        "postgresql_data"
        "redis_data"
        "grafana_data"
        "prometheus_data"
        "n8n_data"
        "jellyfin_config"
        "ollama_data"
        "syncthing_config"
        "minio_data"
    )

    for vol in "${VOLUMES_TO_BACKUP[@]}"; do
        if docker volume inspect "$vol" &>/dev/null; then
            log "  Backing up volume: $vol"
            docker run --rm -v "$vol":/data -v "$BACKUP_DIR":/backup alpine \
                tar czf "/backup/${vol}.tar.gz" /data 2>/dev/null || warn "Failed to backup $vol"
        fi
    done

    # Backup kubeconfig
    cp ~/.kube/config "$BACKUP_DIR/kubeconfig.yaml" 2>/dev/null || true

    log "Backup complete: $BACKUP_DIR"
    ls -la "$BACKUP_DIR"
}

# Step 2: Stop K3d
stop_k3d() {
    log "Step 2: Stopping K3d cluster..."

    # Check if K3d is running
    if command -v k3d &>/dev/null; then
        if k3d cluster list 2>/dev/null | grep -q "running"; then
            log "Stopping K3d clusters..."
            k3d cluster stop --all
            log "K3d clusters stopped"
        else
            info "No running K3d clusters found"
        fi
    else
        info "K3d not installed, skipping"
    fi

    # Note: Docker services continue running
    # They will be migrated to K3s later
    info "Docker services are still running"
    info "They will continue to serve traffic during migration"
}

# Step 3: Install K3s
install_k3s() {
    log "Step 3: Installing native K3s..."

    if systemctl is-active --quiet k3s 2>/dev/null; then
        warn "K3s is already running"
        read -p "Reinstall? (y/N): " choice
        [ "$choice" != "y" ] && return
    fi

    # Run installation script
    sudo "$SCRIPT_DIR/install-k3s-cluster.sh" server-init

    # Wait for cluster
    log "Waiting for cluster to be ready..."
    sleep 15
    kubectl wait --for=condition=Ready node --all --timeout=120s

    log "K3s installed successfully"
    kubectl get nodes
}

# Step 4: Bootstrap cluster
bootstrap() {
    log "Step 4: Bootstrapping cluster components..."

    "$SCRIPT_DIR/bootstrap-cluster.sh"

    log "Bootstrap complete"
}

# Step 5: Deploy applications
deploy() {
    log "Step 5: Deploying applications via ArgoCD..."

    # Apply namespaces first
    log "Creating namespaces..."
    kubectl apply -f "$HOMELAB_DIR/alef/infrastructure/namespaces.yaml"

    # Apply cloudflared
    log "Deploying cloudflared..."
    if [ -f "$HOMELAB_DIR/services/cloudflare-tunnel/credentials.json" ]; then
        kubectl create secret generic cloudflare-tunnel-credentials \
            --namespace ingress-system \
            --from-file=credentials.json="$HOMELAB_DIR/services/cloudflare-tunnel/credentials.json" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    kubectl apply -f "$HOMELAB_DIR/alef/infrastructure/cloudflared.yaml"

    # Apply ArgoCD app-of-apps
    log "Applying ArgoCD app-of-apps..."
    kubectl apply -f "$HOMELAB_DIR/alef/argocd/app-of-apps.yaml"

    # Wait for ArgoCD to sync
    log "Waiting for ArgoCD to sync applications..."
    sleep 30

    log "Applications deployed"
    kubectl get applications -n argocd
}

# Step 6: Verify migration
verify() {
    log "Step 6: Verifying migration..."

    echo ""
    info "Cluster Status:"
    kubectl get nodes

    echo ""
    info "Namespaces:"
    kubectl get namespaces

    echo ""
    info "Pods (all namespaces):"
    kubectl get pods -A

    echo ""
    info "Services:"
    kubectl get svc -A | grep -v "kubernetes"

    echo ""
    info "Ingresses:"
    kubectl get ingress -A

    echo ""
    info "ArgoCD Applications:"
    kubectl get applications -n argocd 2>/dev/null || warn "ArgoCD not yet ready"

    echo ""
    info "Cloudflared Status:"
    kubectl get pods -n ingress-system -l app=cloudflared

    # Test DNS resolution
    echo ""
    info "Testing DNS resolution..."
    for domain in argocd.leopaska.xyz traefik.leopaska.xyz grafana.leopaska.xyz; do
        if dig +short "$domain" @1.1.1.1 &>/dev/null; then
            echo "  ✅ $domain"
        else
            echo "  ❌ $domain"
        fi
    done
}

# Full migration
full_migration() {
    log "Starting full K3d to K3s migration..."
    echo ""

    read -p "This will migrate your cluster. Continue? (y/N): " confirm
    [ "$confirm" != "y" ] && exit 0

    backup
    echo ""

    read -p "Ready to stop K3d? (y/N): " confirm
    [ "$confirm" != "y" ] && exit 0
    stop_k3d
    echo ""

    read -p "Ready to install K3s? (y/N): " confirm
    [ "$confirm" != "y" ] && exit 0
    install_k3s
    echo ""

    bootstrap
    echo ""

    deploy
    echo ""

    verify
    echo ""

    log "============================================"
    log "Migration complete!"
    log "============================================"
    echo ""
    echo "Backup location: $BACKUP_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Verify all services at https://argocd.leopaska.xyz"
    echo "  2. Check individual app domains"
    echo "  3. Migrate Docker volumes to K3s PVCs as needed"
    echo "  4. Delete K3d: k3d cluster delete --all"
    echo ""
}

# Main
case "${1:-help}" in
    backup)
        backup
        ;;
    stop)
        stop_k3d
        ;;
    install)
        install_k3s
        ;;
    bootstrap)
        bootstrap
        ;;
    deploy)
        deploy
        ;;
    verify)
        verify
        ;;
    full)
        full_migration
        ;;
    *)
        echo "K3d to K3s Migration Script"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  backup     Backup current K3d state and Docker volumes"
        echo "  stop       Stop K3d clusters"
        echo "  install    Install native K3s"
        echo "  bootstrap  Install Traefik, ArgoCD, etc."
        echo "  deploy     Deploy applications via ArgoCD"
        echo "  verify     Verify migration success"
        echo "  full       Run all steps with prompts"
        echo ""
        echo "Recommended order: backup → stop → install → bootstrap → deploy → verify"
        ;;
esac
