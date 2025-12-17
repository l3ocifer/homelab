#!/bin/bash
# K3s Cluster Bootstrap Script
# Installs core components after K3s is running:
# - Traefik (ingress controller)
# - cert-manager
# - Sealed Secrets
# - ArgoCD
# - Cloudflared (tunnel)
#
# Usage: ./bootstrap-cluster.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="/home/l3o/git/homelab"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[Bootstrap]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Check kubectl is working
check_cluster() {
    log "Checking cluster connectivity..."
    kubectl cluster-info || { echo "Cannot connect to cluster"; exit 1; }
    kubectl get nodes || { echo "Cannot list nodes"; exit 1; }
    log "Cluster is accessible"
}

# Install Traefik
install_traefik() {
    log "Installing Traefik..."

    # Add Traefik Helm repo
    helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
    helm repo update

    # Create namespace
    kubectl create namespace ingress-system --dry-run=client -o yaml | kubectl apply -f -

    # Install Traefik
    helm upgrade --install traefik traefik/traefik \
        --namespace ingress-system \
        --set service.type=ClusterIP \
        --set ingressRoute.dashboard.enabled=true \
        --set providers.kubernetesIngress.enabled=true \
        --set providers.kubernetesCRD.enabled=true \
        --set logs.general.level=INFO \
        --set logs.access.enabled=true \
        --set metrics.prometheus.enabled=true \
        --set deployment.replicas=2 \
        --wait

    log "Traefik installed"
}

# Install cert-manager
install_cert_manager() {
    log "Installing cert-manager..."

    # Add Jetstack Helm repo
    helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
    helm repo update

    # Install CRDs
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.crds.yaml

    # Install cert-manager
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=false \
        --wait

    # Create ClusterIssuer for Let's Encrypt (staging first for testing)
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: lpask001@gmail.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: traefik
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: lpask001@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

    log "cert-manager installed"
}

# Install Sealed Secrets
install_sealed_secrets() {
    log "Installing Sealed Secrets..."

    # Add Bitnami Helm repo
    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets 2>/dev/null || true
    helm repo update

    # Install Sealed Secrets controller
    helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --namespace kube-system \
        --set fullnameOverride=sealed-secrets-controller \
        --wait

    log "Sealed Secrets installed"
    log "To seal secrets, use: kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system"
}

# Install ArgoCD
install_argocd() {
    log "Installing ArgoCD..."

    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    # Wait for ArgoCD to be ready
    log "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

    # Create Ingress for ArgoCD
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
    - host: argocd.leopaska.xyz
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
EOF

    # Get initial admin password
    log "ArgoCD installed"
    echo ""
    echo "ArgoCD Admin Password:"
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    echo ""
    echo ""
    echo "Access ArgoCD at: https://argocd.leopaska.xyz"
}

# Apply root ArgoCD application (app-of-apps pattern)
apply_root_app() {
    log "Applying ArgoCD root application..."

    # Apply the homelab project
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: homelab
  namespace: argocd
spec:
  description: Homelab applications
  sourceRepos:
    - 'https://github.com/l3ocifer/*'
    - 'https://github.com/potluck-pub/*'
    - 'https://github.com/AuthorWorks/*'
    - 'https://github.com/omnilemma/*'
    - 'https://github.com/the-blink/*'
    - 'https://github.com/ursulai/*'
    - 'https://github.com/pieroot42/*'
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
EOF

    # Apply the root app
    kubectl apply -f "${HOMELAB_DIR}/alef/argocd/root-app.yaml"

    log "Root application applied"
}

# Install cloudflared
install_cloudflared() {
    log "Installing cloudflared..."

    # Check if credentials exist
    CREDS_FILE="${HOMELAB_DIR}/services/cloudflare-tunnel/credentials.json"
    if [ ! -f "$CREDS_FILE" ]; then
        warn "Cloudflare tunnel credentials not found at $CREDS_FILE"
        warn "Skipping cloudflared installation"
        warn "Run 'cloudflared tunnel create homelab' to create tunnel first"
        return
    fi

    # Create namespace
    kubectl create namespace ingress-system --dry-run=client -o yaml | kubectl apply -f -

    # Create secret from credentials
    kubectl create secret generic cloudflare-tunnel-credentials \
        --namespace ingress-system \
        --from-file=credentials.json="$CREDS_FILE" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Apply cloudflared deployment (assumes it exists in alef)
    if [ -f "${HOMELAB_DIR}/alef/config/cloudflare-tunnel-k3s.yml" ]; then
        kubectl apply -f "${HOMELAB_DIR}/alef/config/cloudflare-tunnel-k3s.yml"
        log "cloudflared installed"
    else
        warn "cloudflared config not found, skipping"
    fi
}

# Main
main() {
    log "Starting K3s cluster bootstrap..."
    echo ""

    check_cluster

    install_traefik
    install_cert_manager
    install_sealed_secrets
    install_argocd
    install_cloudflared
    apply_root_app

    echo ""
    log "============================================"
    log "Bootstrap complete!"
    log "============================================"
    echo ""
    echo "Installed components:"
    echo "  ✅ Traefik (ingress controller)"
    echo "  ✅ cert-manager (TLS certificates)"
    echo "  ✅ Sealed Secrets (secret management)"
    echo "  ✅ ArgoCD (GitOps)"
    echo "  ✅ cloudflared (tunnel)"
    echo ""
    echo "Next steps:"
    echo "  1. Access ArgoCD: https://argocd.leopaska.xyz"
    echo "  2. Sync applications in ArgoCD UI"
    echo "  3. Verify services: kubectl get pods -A"
    echo ""
}

main "$@"
