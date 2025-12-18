#!/bin/bash
# Full K3s Cluster Bootstrap Script
# ==================================
# Provisions the entire homelab from scratch
# Run this after K3s is installed to deploy all services
#
# Usage:
#   ./bootstrap-full.sh              # Full bootstrap
#   ./bootstrap-full.sh --dry-run    # Show what would be done
#   ./bootstrap-full.sh <step>       # Run specific step
#
# Steps:
#   prereqs     - Install required CLI tools
#   namespaces  - Create all namespaces
#   sealed      - Install Sealed Secrets controller
#   certs       - Install cert-manager + ClusterIssuers
#   traefik     - Configure Traefik ingress
#   argocd      - Install and configure ArgoCD
#   cloudflared - Deploy Cloudflare tunnel
#   secrets     - Seal and deploy secrets
#   apps        - Deploy all apps via ArgoCD
#   verify      - Verify all services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
ALEF_DIR="${HOMELAB_DIR}/alef"

# Versions
SEALED_SECRETS_VERSION="2.16.1"
KUBESEAL_VERSION="0.27.3"
CERT_MANAGER_VERSION="v1.14.4"
ARGOCD_VERSION="7.3.11"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[BOOTSTRAP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

DRY_RUN="${DRY_RUN:-false}"
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true && shift

run() {
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

# ===========================================================================
# PREREQUISITES
# ===========================================================================
step_prereqs() {
    log "Installing prerequisites..."

    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        error "kubectl not found. Install K3s first."
        exit 1
    fi

    # Check helm
    if ! command -v helm &>/dev/null; then
        log "Installing Helm..."
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi

    # Check kubeseal
    if ! command -v kubeseal &>/dev/null; then
        log "Installing kubeseal v${KUBESEAL_VERSION}..."
        curl -sLo /tmp/kubeseal.tar.gz \
            "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
        tar -xzf /tmp/kubeseal.tar.gz -C /tmp kubeseal
        sudo mv /tmp/kubeseal /usr/local/bin/kubeseal
        sudo chmod +x /usr/local/bin/kubeseal
        rm /tmp/kubeseal.tar.gz
    fi

    log "✅ Prerequisites installed"
    echo "  kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    echo "  helm: $(helm version --short)"
    echo "  kubeseal: $(kubeseal --version)"
}

# ===========================================================================
# NAMESPACES
# ===========================================================================
step_namespaces() {
    log "Creating namespaces..."
    run kubectl apply -f "${ALEF_DIR}/infrastructure/namespaces.yaml"
    log "✅ Namespaces created"
}

# ===========================================================================
# SEALED SECRETS
# ===========================================================================
step_sealed() {
    log "Installing Sealed Secrets controller..."

    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets 2>/dev/null || true
    helm repo update sealed-secrets

    run helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --namespace kube-system \
        --version "${SEALED_SECRETS_VERSION}" \
        --set fullnameOverride=sealed-secrets-controller \
        --wait --timeout 120s

    # Fetch public certificate
    log "Fetching public certificate..."
    sleep 5  # Wait for controller to be ready
    kubeseal --controller-name=sealed-secrets-controller \
             --controller-namespace=kube-system \
             --fetch-cert > "${ALEF_DIR}/secrets/pub-sealed-secrets.pem"

    log "✅ Sealed Secrets installed"
    info "Certificate saved to: ${ALEF_DIR}/secrets/pub-sealed-secrets.pem"
}

# ===========================================================================
# CERT-MANAGER
# ===========================================================================
step_certs() {
    log "Installing cert-manager..."

    helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
    helm repo update jetstack

    run helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version "${CERT_MANAGER_VERSION}" \
        --set installCRDs=true \
        --wait --timeout 120s

    # Create ClusterIssuers
    log "Creating Let's Encrypt ClusterIssuers..."
    cat <<EOF | run kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: lpask001@gmail.com
    privateKeySecretRef:
      name: letsencrypt-staging-key
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
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: traefik
EOF

    log "✅ cert-manager installed"
}

# ===========================================================================
# TRAEFIK CONFIG
# ===========================================================================
step_traefik() {
    log "Configuring Traefik..."
    run kubectl apply -f "${ALEF_DIR}/infrastructure/traefik-config.yaml"
    log "✅ Traefik configured"
}

# ===========================================================================
# ARGOCD
# ===========================================================================
step_argocd() {
    log "Installing ArgoCD..."

    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update argo

    run helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --version "${ARGOCD_VERSION}" \
        --set configs.params."server\.insecure"=true \
        --set server.ingress.enabled=false \
        --wait --timeout 180s

    # Create ArgoCD Ingress
    cat <<EOF | run kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd
  namespace: argocd
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`argocd.leopaska.xyz\`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
EOF

    # Create infrastructure project
    cat <<EOF | run kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: infrastructure
  namespace: argocd
spec:
  description: Infrastructure components
  sourceRepos:
    - '*'
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
EOF

    log "✅ ArgoCD installed"

    # Get admin password
    ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    info "ArgoCD admin password: ${ARGOCD_PASS}"
    info "Access at: https://argocd.leopaska.xyz"
}

# ===========================================================================
# CLOUDFLARED
# ===========================================================================
step_cloudflared() {
    log "Deploying Cloudflared tunnel..."

    # Check for tunnel credentials
    CREDS_FILE="$HOME/.cloudflared/8a8129e7-f8c3-4cc4-8b1f-9995da97fff0.json"
    if [ ! -f "$CREDS_FILE" ]; then
        warn "Tunnel credentials not found at $CREDS_FILE"
        warn "Create the secret manually:"
        echo "  kubectl create secret generic cloudflare-tunnel-credentials \\"
        echo "    --namespace ingress-system \\"
        echo "    --from-file=credentials.json=$CREDS_FILE"
        return 1
    fi

    # Create tunnel credentials secret
    run kubectl create secret generic cloudflare-tunnel-credentials \
        --namespace ingress-system \
        --from-file=credentials.json="$CREDS_FILE" \
        --dry-run=client -o yaml | run kubectl apply -f -

    # Deploy cloudflared
    run kubectl apply -f "${ALEF_DIR}/infrastructure/cloudflared.yaml"

    log "✅ Cloudflared deployed"
}

# ===========================================================================
# SECRETS
# ===========================================================================
step_secrets() {
    log "Deploying sealed secrets..."

    # Check if sealed secrets exist
    if [ ! "$(ls -A "${ALEF_DIR}/secrets/sealed/"*.yaml 2>/dev/null)" ]; then
        warn "No sealed secrets found in ${ALEF_DIR}/secrets/sealed/"
        warn "Create secrets first:"
        echo "  cd ${ALEF_DIR}/secrets"
        echo "  cp templates/secrets.env.example templates/secrets.env"
        echo "  # Edit secrets.env with real values"
        echo "  source templates/secrets.env"
        echo "  ./seal-secrets.sh --all"
        return 1
    fi

    run kubectl apply -f "${ALEF_DIR}/secrets/sealed/"
    log "✅ Secrets deployed"
}

# ===========================================================================
# APPS (via ArgoCD)
# ===========================================================================
step_apps() {
    log "Deploying apps via ArgoCD..."

    # Deploy the root App of Apps (includes project definition)
    run kubectl apply -f "${ALEF_DIR}/argocd/app-of-apps.yaml"

    # Wait for root app to sync
    log "Waiting for ArgoCD to sync..."
    sleep 10

    log "✅ ArgoCD App-of-Apps deployed"
    info "ArgoCD will now sync all services from argocd/apps/"
    info "Check progress at: https://argocd.leopaska.xyz"
}

# ===========================================================================
# VERIFY
# ===========================================================================
step_verify() {
    log "Verifying deployment..."
    echo ""

    echo "=== Namespaces ==="
    kubectl get ns | grep -E "^(ingress|cert|monitoring|argocd|ai|media|productivity|security|storage|databases|potluck|blink|authorworks|omnilemma|hyvapaska|ursulai|ae|githired|chimera|lunasea|trade)"
    echo ""

    echo "=== Pods (non-kube-system) ==="
    kubectl get pods -A | grep -v kube-system | head -30
    echo ""

    echo "=== Ingresses ==="
    kubectl get ingressroute -A 2>/dev/null | head -20 || echo "No IngressRoutes found"
    echo ""

    echo "=== ArgoCD Apps ==="
    kubectl get applications -n argocd 2>/dev/null || echo "No ArgoCD apps found"
    echo ""

    log "Verification complete"
    info "Check ArgoCD at: https://argocd.leopaska.xyz"
}

# ===========================================================================
# FULL BOOTSTRAP
# ===========================================================================
full_bootstrap() {
    log "=========================================="
    log "Starting Full K3s Bootstrap"
    log "=========================================="
    echo ""

    # Check cluster is accessible
    if ! kubectl cluster-info &>/dev/null; then
        error "Cannot connect to K3s cluster"
        exit 1
    fi

    step_prereqs
    echo ""

    step_namespaces
    echo ""

    step_sealed
    echo ""

    step_certs
    echo ""

    step_traefik
    echo ""

    step_argocd
    echo ""

    step_cloudflared
    echo ""

    # step_secrets  # Skip if secrets not yet created
    # echo ""

    step_apps
    echo ""

    step_verify

    log "=========================================="
    log "Bootstrap Complete!"
    log "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Create sealed secrets:"
    echo "     cd ${ALEF_DIR}/secrets"
    echo "     cp templates/secrets.env.example templates/secrets.env"
    echo "     # Edit with real values"
    echo "     source templates/secrets.env && ./seal-secrets.sh --all"
    echo ""
    echo "  2. Check ArgoCD: https://argocd.leopaska.xyz"
    echo ""
    echo "  3. Sync apps in ArgoCD UI or:"
    echo "     argocd app sync --all"
    echo ""
}

# ===========================================================================
# MAIN
# ===========================================================================
case "${1:-full}" in
    prereqs)    step_prereqs ;;
    namespaces) step_namespaces ;;
    sealed)     step_sealed ;;
    certs)      step_certs ;;
    traefik)    step_traefik ;;
    argocd)     step_argocd ;;
    cloudflared) step_cloudflared ;;
    secrets)    step_secrets ;;
    apps)       step_apps ;;
    verify)     step_verify ;;
    full)       full_bootstrap ;;
    *)
        echo "K3s Cluster Bootstrap Script"
        echo ""
        echo "Usage: $0 [--dry-run] [step]"
        echo ""
        echo "Steps:"
        echo "  full        Run all steps (default)"
        echo "  prereqs     Install CLI tools (helm, kubeseal)"
        echo "  namespaces  Create K8s namespaces"
        echo "  sealed      Install Sealed Secrets controller"
        echo "  certs       Install cert-manager"
        echo "  traefik     Configure Traefik ingress"
        echo "  argocd      Install ArgoCD"
        echo "  cloudflared Deploy Cloudflare tunnel"
        echo "  secrets     Deploy sealed secrets"
        echo "  apps        Deploy ArgoCD applications"
        echo "  verify      Verify deployment"
        echo ""
        echo "Options:"
        echo "  --dry-run   Show what would be done"
        ;;
esac
