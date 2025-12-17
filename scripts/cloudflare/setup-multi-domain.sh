#!/bin/bash
# Multi-Domain Cloudflare Setup Script
# Adds multiple domains to Cloudflare and creates tunnel DNS records
#
# Prerequisites:
#   - Cloudflare account with domains added
#   - cloudflared installed
#   - CLOUDFLARE_API_TOKEN set
#
# Usage:
#   ./setup-multi-domain.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[CF]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check prerequisites
check_prereqs() {
    command -v cloudflared &>/dev/null || error "cloudflared not installed"
    command -v jq &>/dev/null || error "jq not installed"
    [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || error "CLOUDFLARE_API_TOKEN not set"
}

# Get zone ID for a domain
get_zone_id() {
    local domain="$1"
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | \
        jq -r '.result[0].id // empty'
}

# Get tunnel ID
get_tunnel_id() {
    local creds_file="/home/l3o/git/homelab/services/cloudflare-tunnel/credentials.json"
    if [ -f "$creds_file" ]; then
        jq -r '.TunnelID' "$creds_file"
    else
        cloudflared tunnel list --output json | jq -r '.[0].id'
    fi
}

# Create CNAME record for tunnel
create_tunnel_cname() {
    local zone_id="$1"
    local subdomain="$2"
    local tunnel_id="$3"

    local tunnel_cname="${tunnel_id}.cfargotunnel.com"

    # Check if record exists
    local existing=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${subdomain}&type=CNAME" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | jq -r '.result[0].id // empty')

    if [ -n "$existing" ]; then
        info "Updating existing CNAME: $subdomain"
        curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${existing}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"${subdomain}\",\"content\":\"${tunnel_cname}\",\"proxied\":true}" | \
            jq -r 'if .success then "✅ Updated" else "❌ \(.errors[0].message)" end'
    else
        info "Creating CNAME: $subdomain -> $tunnel_cname"
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"${subdomain}\",\"content\":\"${tunnel_cname}\",\"proxied\":true}" | \
            jq -r 'if .success then "✅ Created" else "❌ \(.errors[0].message)" end'
    fi
}

# Setup domain with tunnel records
setup_domain() {
    local domain="$1"
    shift
    local subdomains=("$@")

    log "Setting up domain: $domain"

    # Get zone ID
    local zone_id=$(get_zone_id "$domain")
    if [ -z "$zone_id" ]; then
        warn "Domain $domain not found in Cloudflare. Add it first."
        return 1
    fi

    info "Zone ID: $zone_id"

    # Get tunnel ID
    local tunnel_id=$(get_tunnel_id)
    if [ -z "$tunnel_id" ]; then
        error "No tunnel found. Create one first: cloudflared tunnel create homelab"
    fi

    info "Tunnel ID: $tunnel_id"

    # Create root domain CNAME
    create_tunnel_cname "$zone_id" "@" "$tunnel_id"

    # Create wildcard CNAME
    create_tunnel_cname "$zone_id" "*" "$tunnel_id"

    # Create specific subdomains
    for sub in "${subdomains[@]}"; do
        create_tunnel_cname "$zone_id" "$sub" "$tunnel_id"
        sleep 0.2  # Rate limiting
    done

    log "Domain $domain setup complete"
    echo ""
}

# List all configured zones
list_zones() {
    log "Fetching Cloudflare zones..."

    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?per_page=50" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | \
        jq -r '.result[] | "\(.name)\t\(.id)\t\(.status)"' | column -t
}

# Main setup
main() {
    check_prereqs

    log "Multi-Domain Cloudflare Setup"
    echo ""

    # List current zones
    info "Current Cloudflare zones:"
    list_zones
    echo ""

    # Setup each domain
    # leopaska.xyz - Main homelab
    setup_domain "leopaska.xyz" \
        "traefik" "argocd" "grafana" "prometheus" "loki" \
        "workflow" "openwebui" "homeassistant" "jellyfin" "warden" \
        "minio" "coolify" "pgadmin" "ssh" "mcp" \
        "localist" "potluck" "blink" "ae" "authorworks" \
        "trade" "ursulai" "omni" "hyva"

    # Additional domains - uncomment as you add them to Cloudflare
    # setup_domain "ursulai.com" "app" "api" "www"
    # setup_domain "authorworks.io" "app" "api" "www"
    # setup_domain "potluck.pub" "app" "api" "www"
    # setup_domain "theblink.live" "app" "api" "rtmp" "hls"
    # setup_domain "omnilemma.com" "app" "api" "www"

    log "============================================"
    log "Multi-domain setup complete!"
    log "============================================"
    echo ""
    echo "Next steps:"
    echo "  1. Update cloudflared config with multi-domain-tunnel.yaml"
    echo "  2. Restart cloudflared: sudo systemctl restart alef-cloudflare-tunnel"
    echo "  3. Verify DNS: dig argocd.leopaska.xyz"
    echo ""
}

# Parse arguments
case "${1:-setup}" in
    setup)
        main
        ;;
    list)
        check_prereqs
        list_zones
        ;;
    domain)
        check_prereqs
        shift
        setup_domain "$@"
        ;;
    *)
        echo "Multi-Domain Cloudflare Setup"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  setup         Setup all domains (default)"
        echo "  list          List Cloudflare zones"
        echo "  domain <dom>  Setup specific domain"
        ;;
esac
