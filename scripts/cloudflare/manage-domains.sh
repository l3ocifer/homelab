#!/bin/bash
# Cloudflare Domain Management Script
# ====================================
# Manages all production domains from domains.yaml configuration
#
# Usage:
#   ./manage-domains.sh list          # List all configured domains
#   ./manage-domains.sh status        # Check Cloudflare status of all domains
#   ./manage-domains.sh add <domain>  # Add a new domain to Cloudflare
#   ./manage-domains.sh sync          # Sync all domains (add missing, create DNS)
#   ./manage-domains.sh update-ns     # Update nameservers at registrars

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/domains.yaml"
ZSHRC="$HOME/.zshrc"

# Load tokens from environment or zshrc
source "$ZSHRC" 2>/dev/null || true

CF_TOKEN="${CLOUDFLARE_ADMIN_TOKEN:-gB5OXwfx3zTOu0bEAZq4o7JaNteItmasclCSxYvw}"
ACCOUNT_ID="23e8fcd92ab0244ef1a1472a2538bafd"
TUNNEL_ID="8a8129e7-f8c3-4cc4-8b1f-9995da97fff0"
TUNNEL_CNAME="${TUNNEL_ID}.cfargotunnel.com"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[CF]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Get all domains from config
get_domains() {
    yq -r '.domains[].name' "$CONFIG_FILE" 2>/dev/null || \
    grep -E "^  - name:" "$CONFIG_FILE" | awk '{print $3}'
}

# Get zone ID for a domain from Cloudflare
get_zone_id() {
    local domain="$1"
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result[0].id // empty'
}

# Get zone status
get_zone_status() {
    local domain="$1"
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result[0].status // "not_found"'
}

# Add domain to Cloudflare
add_domain() {
    local domain="$1"

    log "Adding $domain to Cloudflare..."

    result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"name\":\"${domain}\",\"account\":{\"id\":\"${ACCOUNT_ID}\"},\"jump_start\":true}")

    if echo "$result" | jq -e '.success' &>/dev/null; then
        zone_id=$(echo "$result" | jq -r '.result.id')
        ns=$(echo "$result" | jq -r '.result.name_servers | join(", ")')
        log "✅ Added: $domain"
        info "  Zone ID: $zone_id"
        info "  Nameservers: $ns"

        # Create DNS records
        create_dns_records "$zone_id" "$domain"

        echo "$zone_id"
    else
        error_msg=$(echo "$result" | jq -r '.errors[0].message // "Unknown error"')
        if echo "$error_msg" | grep -q "already exists"; then
            warn "$domain already exists in Cloudflare"
            get_zone_id "$domain"
        else
            error "Failed to add $domain: $error_msg"
            return 1
        fi
    fi
}

# Create DNS records for a domain
create_dns_records() {
    local zone_id="$1"
    local domain="$2"

    info "Creating DNS records for $domain..."

    for name in "@" "www" "*" "api" "app"; do
        result=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "Authorization: Bearer $CF_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"${name}\",\"content\":\"${TUNNEL_CNAME}\",\"proxied\":true}")

        if echo "$result" | jq -e '.success' &>/dev/null; then
            echo -n "  ✅ $name "
        else
            echo -n "  ⚠️ $name "
        fi
        sleep 0.1
    done
    echo ""
}

# Update nameservers at Route53
update_nameservers() {
    local domain="$1"
    local aws_account="${2:-pie}"

    log "Updating nameservers for $domain (AWS: $aws_account)..."

    # Switch AWS profile
    export AWS_PROFILE="aws-${aws_account}-iam-leo"

    result=$(aws route53domains update-domain-nameservers \
        --domain-name "$domain" \
        --nameservers Name=cris.ns.cloudflare.com Name=rosemary.ns.cloudflare.com 2>&1)

    if echo "$result" | grep -q "OperationId"; then
        log "✅ Nameservers updated for $domain"
    else
        error "Failed to update nameservers for $domain: $result"
    fi
}

# List all domains
cmd_list() {
    log "Configured domains:"
    echo ""
    get_domains | while read domain; do
        echo "  - $domain"
    done
}

# Check status of all domains
cmd_status() {
    log "Checking Cloudflare status for all domains..."
    echo ""
    printf "%-25s %-15s %-40s\n" "DOMAIN" "STATUS" "ZONE ID"
    printf "%-25s %-15s %-40s\n" "------" "------" "-------"

    get_domains | while read domain; do
        zone_id=$(get_zone_id "$domain")
        status=$(get_zone_status "$domain")

        case "$status" in
            active)   status_color="${GREEN}active${NC}" ;;
            pending)  status_color="${YELLOW}pending${NC}" ;;
            *)        status_color="${RED}${status}${NC}" ;;
        esac

        printf "%-25s %-15b %-40s\n" "$domain" "$status_color" "${zone_id:-N/A}"
    done
}

# Add a single domain
cmd_add() {
    local domain="$1"
    [ -z "$domain" ] && error "Usage: $0 add <domain>" && exit 1

    add_domain "$domain"
}

# Sync all domains
cmd_sync() {
    log "Syncing all domains with Cloudflare..."
    echo ""

    get_domains | while read domain; do
        zone_id=$(get_zone_id "$domain")

        if [ -z "$zone_id" ]; then
            add_domain "$domain"
        else
            status=$(get_zone_status "$domain")
            if [ "$status" = "active" ]; then
                echo "✅ $domain (active)"
            else
                echo "⏳ $domain ($status)"
            fi
        fi
    done

    echo ""
    log "Sync complete. Run '$0 status' to check status."
}

# Update nameservers for all pending domains
cmd_update_ns() {
    log "Updating nameservers for pending domains..."
    echo ""

    # This reads the AWS account from the config
    get_domains | while read domain; do
        status=$(get_zone_status "$domain")

        if [ "$status" = "pending" ]; then
            # Get AWS account from config (default to pie)
            aws_account=$(grep -A5 "name: $domain" "$CONFIG_FILE" | grep "aws_account:" | awk '{print $2}' || echo "pie")
            update_nameservers "$domain" "$aws_account"
        fi
    done
}

# Update zshrc with zone IDs
cmd_update_zshrc() {
    log "Updating ~/.zshrc with zone IDs..."

    get_domains | while read domain; do
        zone_id=$(get_zone_id "$domain")
        [ -z "$zone_id" ] && continue

        var_name=$(echo "$domain" | tr '.' '_' | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        var_name="CLOUDFLARE_ZONE_${var_name}"

        if grep -q "^export $var_name=" "$ZSHRC"; then
            sed -i "s|^export $var_name=.*|export $var_name=\"$zone_id\"|" "$ZSHRC"
        else
            echo "export $var_name=\"$zone_id\"" >> "$ZSHRC"
        fi
        echo "  $var_name=$zone_id"
    done

    log "Run 'source ~/.zshrc' to reload"
}

# Main
case "${1:-help}" in
    list)
        cmd_list
        ;;
    status)
        cmd_status
        ;;
    add)
        cmd_add "${2:-}"
        ;;
    sync)
        cmd_sync
        ;;
    update-ns)
        cmd_update_ns
        ;;
    update-zshrc)
        cmd_update_zshrc
        ;;
    *)
        echo "Cloudflare Domain Management"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  list         List all configured domains"
        echo "  status       Check Cloudflare status of all domains"
        echo "  add <domain> Add a new domain to Cloudflare"
        echo "  sync         Sync all domains (add missing, create DNS)"
        echo "  update-ns    Update nameservers at Route53 registrars"
        echo "  update-zshrc Update ~/.zshrc with zone IDs"
        echo ""
        echo "Configuration: $CONFIG_FILE"
        ;;
esac
