#!/bin/bash
# Setup Production Domains in Cloudflare
# =======================================
# This script helps add production domains to Cloudflare and create
# DNS records pointing to the homelab tunnel.
#
# Prerequisites:
#   1. Create a Cloudflare API token with these permissions:
#      - Zone:Zone:Read (all zones)
#      - Zone:DNS:Edit (all zones)
#      Go to: https://dash.cloudflare.com/profile/api-tokens
#
#   2. Export the token:
#      export CLOUDFLARE_DNS_TOKEN="your-token-here"
#
# Usage:
#   ./setup-production-domains.sh list-zones
#   ./setup-production-domains.sh add-tunnel-dns <domain>
#   ./setup-production-domains.sh add-all

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[CF]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Tunnel ID from existing tunnel
TUNNEL_ID="8a8129e7-f8c3-4cc4-8b1f-9995da97fff0"
TUNNEL_CNAME="${TUNNEL_ID}.cfargotunnel.com"

# Production domains to add
# Format: ["domain"]="registrar:zone_id" or ["domain"]="cloudflare:zone_id"
declare -A DOMAINS=(
    # Route53 domains
    ["potluck.pub"]="PIE:Z06744602W9W1NO99WVGH"
    ["theblink.live"]="PIE:Z07306541DD1119Y1CZO9"
    ["author.works"]="LEO:Z05113051O0O0QJB9I8TC"
    ["omnilemma.com"]="PIE:Z07237912PQNZMNTR5QMZ"
    ["hyvapaska.com"]="PIE:Z08020813QWHGM48NU0Q7"
    ["americanangel.xyz"]="PIE:Z07766371J7YL53DSCXBD"
    # Cloudflare domains
    ["ursulai.com"]="cloudflare:0afcbbbda732bf84824aaa2d7960bc41"
    ["githired.work"]="cloudflare:5455229f61b5819fe9d538963461b318"
    ["chimera.red"]="cloudflare:232b91f8bcf179b5b3a80406aacd7693"
    ["lunasea.social"]="cloudflare:ca1949cc0497bbe6b447f075f0f0690a"
)

# Subdomains to create for each domain
COMMON_SUBDOMAINS=("www" "api" "app")

check_prereqs() {
    if [ -z "${CLOUDFLARE_DNS_TOKEN:-}" ]; then
        error "CLOUDFLARE_DNS_TOKEN not set.

Create a token at: https://dash.cloudflare.com/profile/api-tokens

Required permissions:
  - Zone:Zone:Read (all zones)
  - Zone:DNS:Edit (all zones)

Then run:
  export CLOUDFLARE_DNS_TOKEN='your-token-here'
"
    fi

    command -v curl &>/dev/null || error "curl not found"
    command -v jq &>/dev/null || error "jq not found"
}

# Test token
test_token() {
    log "Testing Cloudflare API token..."
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer ${CLOUDFLARE_DNS_TOKEN}")

    if echo "$response" | jq -e '.success' &>/dev/null; then
        log "Token is valid"
        return 0
    else
        error "Invalid token: $(echo "$response" | jq -r '.errors[0].message')"
    fi
}

# List all zones
list_zones() {
    check_prereqs
    log "Fetching Cloudflare zones..."

    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?per_page=50" \
        -H "Authorization: Bearer ${CLOUDFLARE_DNS_TOKEN}" | \
        jq -r '.result[] | "\(.name)\t\(.id)\t\(.status)"' | column -t
}

# Get zone ID for a domain
get_zone_id() {
    local domain="$1"

    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "Authorization: Bearer ${CLOUDFLARE_DNS_TOKEN}" | \
        jq -r '.result[0].id // empty'
}

# Create CNAME record pointing to tunnel
create_tunnel_cname() {
    local zone_id="$1"
    local name="$2"  # subdomain or @ for root

    local record_name="$name"

    info "Creating CNAME: $name -> $TUNNEL_CNAME"

    # Check if record exists
    existing=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${name}&type=CNAME" \
        -H "Authorization: Bearer ${CLOUDFLARE_DNS_TOKEN}" | jq -r '.result[0].id // empty')

    if [ -n "$existing" ]; then
        # Update existing record
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${existing}" \
            -H "Authorization: Bearer ${CLOUDFLARE_DNS_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"${name}\",\"content\":\"${TUNNEL_CNAME}\",\"proxied\":true}" | \
            jq -r 'if .success then "  ✅ Updated" else "  ❌ \(.errors[0].message)" end'
    else
        # Create new record
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "Authorization: Bearer ${CLOUDFLARE_DNS_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"${name}\",\"content\":\"${TUNNEL_CNAME}\",\"proxied\":true}" | \
            jq -r 'if .success then "  ✅ Created" else "  ❌ \(.errors[0].message)" end'
    fi
}

# Setup DNS for a single domain
setup_domain_dns() {
    local domain="$1"

    log "Setting up DNS for: $domain"

    zone_id=$(get_zone_id "$domain")

    if [ -z "$zone_id" ]; then
        warn "Domain $domain not found in Cloudflare. Add it first:"
        echo "  1. Go to https://dash.cloudflare.com"
        echo "  2. Click 'Add a Site'"
        echo "  3. Enter: $domain"
        echo "  4. Update nameservers at registrar"
        return 1
    fi

    info "Zone ID: $zone_id"

    # Create root domain CNAME (or A record alias)
    create_tunnel_cname "$zone_id" "@"

    # Create www subdomain
    create_tunnel_cname "$zone_id" "www"

    # Create wildcard
    create_tunnel_cname "$zone_id" "*"

    log "DNS setup complete for $domain"
}

# Setup all production domains
setup_all_domains() {
    check_prereqs
    test_token

    log "Setting up all production domains..."
    echo ""

    # First, setup leopaska.xyz (already in Cloudflare)
    log "=== leopaska.xyz (Infrastructure) ==="
    zone_id=$(get_zone_id "leopaska.xyz")
    if [ -n "$zone_id" ]; then
        # Create CNAMEs for all subdomains
        LEOPASKA_SUBDOMAINS=(
            # Infrastructure
            "argocd" "traefik" "grafana" "prometheus" "loki" "uptimekuma"
            # AI
            "ollama" "openwebui" "mcp" "qdrant"
            # Productivity
            "workflow" "homeassistant" "huginn" "postiz" "coolify"
            # Storage
            "minio" "syncthing" "pgadmin" "adminer" "whodb"
            # Security
            "warden" "authelia" "rustdesk"
            # Communication
            "conduit" "element" "rustpad"
            # Media
            "jellyfin"
            # Production app subdomains
            "potluck" "blink" "ae" "hyva" "omni" "ursulai" "authorworks" "trade"
            "githired" "chimera" "lunasea"
        )

        for sub in "${LEOPASKA_SUBDOMAINS[@]}"; do
            create_tunnel_cname "$zone_id" "$sub"
            sleep 0.1
        done
    fi
    echo ""

    # Setup each production domain
    for domain in "${!DOMAINS[@]}"; do
        log "=== $domain ==="
        setup_domain_dns "$domain" || true
        echo ""
    done

    log "============================================"
    log "DNS setup complete!"
    log "============================================"
    echo ""
    echo "Next steps:"
    echo "  1. Update nameservers for domains not yet on Cloudflare"
    echo "  2. Wait for DNS propagation (up to 48 hours)"
    echo "  3. Verify: dig potluck.pub @1.1.1.1"
}

# Show migration instructions
show_instructions() {
    cat <<'EOF'
=============================================================================
CLOUDFLARE PRODUCTION DOMAIN SETUP
=============================================================================

STEP 1: Create API Token
-------------------------
Go to: https://dash.cloudflare.com/profile/api-tokens

Click "Create Token" and use these permissions:
  - Zone:Zone:Read (All zones)
  - Zone:DNS:Edit (All zones)

Save the token and run:
  export CLOUDFLARE_DNS_TOKEN='your-token-here'

STEP 2: Add Domains to Cloudflare
---------------------------------
For each domain, go to https://dash.cloudflare.com and click "Add a Site":
  - potluck.pub
  - theblink.live
  - author.works
  - omnilemma.com
  - hyvapaska.com
  - americanangel.xyz

STEP 3: Update Nameservers
--------------------------
After adding each domain, Cloudflare will provide nameservers.
Update them at your registrar (the AWS accounts where domains are registered).

For Route53 registered domains:
  aws route53domains update-domain-nameservers \
    --domain-name potluck.pub \
    --nameservers Name=ns1.cloudflare.com Name=ns2.cloudflare.com

STEP 4: Run This Script
-----------------------
  ./setup-production-domains.sh add-all

This will create CNAME records pointing to the Cloudflare tunnel.

STEP 5: Verify
--------------
  dig potluck.pub @1.1.1.1
  curl -I https://potluck.pub

=============================================================================
EOF
}

# Main
case "${1:-help}" in
    test)
        check_prereqs
        test_token
        ;;
    list-zones)
        list_zones
        ;;
    add-tunnel-dns)
        check_prereqs
        test_token
        setup_domain_dns "${2:-}"
        ;;
    add-all)
        setup_all_domains
        ;;
    instructions|help)
        show_instructions
        ;;
    *)
        echo "Cloudflare Production Domain Setup"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  instructions  Show step-by-step setup guide"
        echo "  test          Test API token"
        echo "  list-zones    List all Cloudflare zones"
        echo "  add-tunnel-dns <domain>  Add DNS for a domain"
        echo "  add-all       Add DNS for all production domains"
        echo ""
        echo "Example:"
        echo "  export CLOUDFLARE_DNS_TOKEN='your-token'"
        echo "  $0 add-all"
        ;;
esac
