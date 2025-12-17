#!/bin/bash
# K3s Cluster Installation Script
# Installs native K3s on homelab servers (migrating from K3d)
#
# Usage:
#   ./install-k3s-cluster.sh server-init    # First server (initializes cluster)
#   ./install-k3s-cluster.sh server-join    # Additional server nodes
#   ./install-k3s-cluster.sh agent          # Worker/agent nodes

set -euo pipefail

# Configuration
CLUSTER_NAME="alef-homelab"
DOMAIN="leopaska.xyz"
K3S_VERSION="v1.29.0+k3s1"  # Pin to stable version

# Network configuration
PRIMARY_SERVER_IP="192.168.1.200"
TAILSCALE_ENABLED=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[K3s]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Get Tailscale IP if available
get_tailscale_ip() {
    if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
        tailscale ip -4 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Pre-flight checks
preflight_check() {
    log "Running pre-flight checks..."

    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root or with sudo"
    fi

    # Check if K3d is running (need to stop it first)
    if command -v k3d &>/dev/null && k3d cluster list 2>/dev/null | grep -q "running"; then
        warn "K3d clusters detected. Please stop them first:"
        echo "  k3d cluster stop --all"
        read -p "Continue anyway? (y/N): " choice
        [ "$choice" != "y" ] && exit 1
    fi

    # Check if K3s is already installed
    if systemctl is-active --quiet k3s 2>/dev/null; then
        warn "K3s is already running on this system"
        read -p "Reinstall? This will reset the cluster. (y/N): " choice
        [ "$choice" != "y" ] && exit 1
        log "Uninstalling existing K3s..."
        /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
    fi

    log "Pre-flight checks passed"
}

# Install K3s as first server (cluster init)
install_server_init() {
    preflight_check

    log "Installing K3s as initial server node..."

    # Build TLS SANs
    TAILSCALE_IP=$(get_tailscale_ip)
    TLS_SANS="--tls-san ${PRIMARY_SERVER_IP} --tls-san k3s.${DOMAIN}"
    [ -n "$TAILSCALE_IP" ] && TLS_SANS="$TLS_SANS --tls-san $TAILSCALE_IP"

    # Install K3s
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server \
        --cluster-init \
        --disable traefik \
        --disable servicelb \
        --write-kubeconfig-mode 644 \
        $TLS_SANS \
        --node-label "node-role.kubernetes.io/control-plane=true" \
        --node-label "topology.kubernetes.io/zone=primary" \
        --kubelet-arg="max-pods=250"

    # Wait for K3s to be ready
    log "Waiting for K3s to be ready..."
    sleep 10
    kubectl wait --for=condition=Ready node --all --timeout=120s

    # Get join token
    TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)

    log "K3s server initialized successfully!"
    echo ""
    echo "============================================"
    echo "Join token for other nodes:"
    echo "$TOKEN"
    echo ""
    echo "Save this token! You'll need it to join other nodes."
    echo "============================================"
    echo ""
    echo "To join another server node:"
    echo "  curl -sfL https://get.k3s.io | K3S_URL=https://${PRIMARY_SERVER_IP}:6443 K3S_TOKEN=\"$TOKEN\" sh -s - server"
    echo ""
    echo "To join a worker node:"
    echo "  curl -sfL https://get.k3s.io | K3S_URL=https://${PRIMARY_SERVER_IP}:6443 K3S_TOKEN=\"$TOKEN\" sh -s - agent"
    echo ""

    # Save token to file
    echo "$TOKEN" > /var/lib/rancher/k3s/server/node-token.txt
    chmod 600 /var/lib/rancher/k3s/server/node-token.txt

    # Copy kubeconfig for user
    mkdir -p /home/l3o/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/l3o/.kube/config
    chown -R l3o:l3o /home/l3o/.kube
    chmod 600 /home/l3o/.kube/config

    log "Kubeconfig copied to /home/l3o/.kube/config"
}

# Install K3s as additional server (HA)
install_server_join() {
    preflight_check

    if [ -z "${K3S_TOKEN:-}" ]; then
        read -p "Enter join token: " K3S_TOKEN
    fi

    log "Installing K3s as additional server node..."

    TAILSCALE_IP=$(get_tailscale_ip)
    TLS_SANS="--tls-san $(hostname -I | awk '{print $1}')"
    [ -n "$TAILSCALE_IP" ] && TLS_SANS="$TLS_SANS --tls-san $TAILSCALE_IP"

    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server \
        --server "https://${PRIMARY_SERVER_IP}:6443" \
        --token "$K3S_TOKEN" \
        --disable traefik \
        --disable servicelb \
        --write-kubeconfig-mode 644 \
        $TLS_SANS \
        --node-label "node-role.kubernetes.io/control-plane=true"

    log "Server node joined successfully!"
}

# Install K3s as agent (worker)
install_agent() {
    preflight_check

    if [ -z "${K3S_TOKEN:-}" ]; then
        read -p "Enter join token: " K3S_TOKEN
    fi

    # Detect node type for labeling
    ARCH=$(uname -m)
    LABELS="--node-label arch=${ARCH}"

    # Check for GPU
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        LABELS="$LABELS --node-label nvidia.com/gpu=true --node-label node-type=gpu"
        log "GPU detected, adding GPU labels"
    fi

    # Check if Raspberry Pi
    if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        LABELS="$LABELS --node-label node-type=raspi"
        log "Raspberry Pi detected"
    fi

    log "Installing K3s agent..."

    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - agent \
        --server "https://${PRIMARY_SERVER_IP}:6443" \
        --token "$K3S_TOKEN" \
        $LABELS

    log "Agent node joined successfully!"
}

# Show cluster status
show_status() {
    if ! command -v kubectl &>/dev/null; then
        error "kubectl not found"
    fi

    echo ""
    log "Cluster Nodes:"
    kubectl get nodes -o wide
    echo ""
    log "System Pods:"
    kubectl get pods -n kube-system
}

# Main
case "${1:-help}" in
    server-init)
        install_server_init
        show_status
        ;;
    server-join)
        install_server_join
        show_status
        ;;
    agent)
        install_agent
        ;;
    status)
        show_status
        ;;
    *)
        echo "K3s Cluster Installation Script"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  server-init   Initialize first server node (creates cluster)"
        echo "  server-join   Join as additional server node (HA)"
        echo "  agent         Join as worker/agent node"
        echo "  status        Show cluster status"
        echo ""
        echo "Environment variables:"
        echo "  K3S_TOKEN     Join token (required for server-join and agent)"
        ;;
esac
