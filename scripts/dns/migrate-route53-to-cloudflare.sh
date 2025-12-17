#!/bin/bash
# DNS Migration Script: Route53 to Cloudflare
# Exports Route53 records and imports them to Cloudflare
#
# Prerequisites:
#   - AWS CLI configured (run 'leo' or 'pie' first)
#   - Cloudflare API token with Zone:Edit permissions
#   - jq installed
#
# Usage:
#   ./migrate-route53-to-cloudflare.sh export   # Export Route53 records
#   ./migrate-route53-to-cloudflare.sh import   # Import to Cloudflare
#   ./migrate-route53-to-cloudflare.sh verify   # Verify migration

set -euo pipefail

# Configuration
EXPORT_DIR="/home/l3o/git/homelab/scripts/dns/exports"
mkdir -p "$EXPORT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[DNS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Check prerequisites
check_prereqs() {
    command -v aws &>/dev/null || error "AWS CLI not found"
    command -v jq &>/dev/null || error "jq not found"
    command -v curl &>/dev/null || error "curl not found"

    [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || error "CLOUDFLARE_API_TOKEN not set. Run 'cf-leo' first."
    [ -n "${CLOUDFLARE_ZONE_ID:-}" ] || error "CLOUDFLARE_ZONE_ID not set. Run 'cf-leo' first."
}

# List Route53 hosted zones
list_zones() {
    log "Listing Route53 hosted zones..."
    aws route53 list-hosted-zones --query 'HostedZones[*].{Name:Name,Id:Id,Private:Config.PrivateZone}' --output table
}

# Export Route53 records
export_records() {
    local ZONE_ID="${1:-}"

    if [ -z "$ZONE_ID" ]; then
        list_zones
        read -p "Enter Zone ID (e.g., Z1234567890ABC): " ZONE_ID
    fi

    # Remove /hostedzone/ prefix if present
    ZONE_ID="${ZONE_ID#/hostedzone/}"

    log "Exporting records from Zone: $ZONE_ID"

    # Get zone name
    ZONE_NAME=$(aws route53 get-hosted-zone --id "$ZONE_ID" --query 'HostedZone.Name' --output text)
    ZONE_NAME="${ZONE_NAME%.}"  # Remove trailing dot

    EXPORT_FILE="${EXPORT_DIR}/${ZONE_NAME}-route53-$(date +%Y%m%d).json"

    # Export records
    aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" > "$EXPORT_FILE"

    # Count records
    RECORD_COUNT=$(jq '.ResourceRecordSets | length' "$EXPORT_FILE")

    log "Exported $RECORD_COUNT records to $EXPORT_FILE"

    # Show summary
    echo ""
    info "Record types found:"
    jq -r '.ResourceRecordSets[].Type' "$EXPORT_FILE" | sort | uniq -c | sort -rn
    echo ""

    # Show records
    info "Records:"
    jq -r '.ResourceRecordSets[] | "\(.Type)\t\(.Name)\t\(.ResourceRecords[0].Value // .AliasTarget.DNSName // "ALIAS")"' "$EXPORT_FILE" | column -t
}

# Convert Route53 record to Cloudflare format
convert_record() {
    local record="$1"
    local zone_name="$2"

    local type=$(echo "$record" | jq -r '.Type')
    local name=$(echo "$record" | jq -r '.Name')
    local ttl=$(echo "$record" | jq -r '.TTL // 1')

    # Remove zone suffix and trailing dot from name
    name="${name%.${zone_name}.}"
    name="${name%.}"
    [ "$name" = "$zone_name" ] && name="@"

    # Skip SOA and NS records for root (Cloudflare manages these)
    if [ "$type" = "SOA" ] || ([ "$type" = "NS" ] && [ "$name" = "@" ]); then
        return
    fi

    # Get value based on record type
    local content=""
    local proxied="false"

    case "$type" in
        A|AAAA)
            content=$(echo "$record" | jq -r '.ResourceRecords[0].Value')
            proxied="true"  # Proxy A/AAAA by default
            ;;
        CNAME)
            content=$(echo "$record" | jq -r '.ResourceRecords[0].Value // .AliasTarget.DNSName')
            content="${content%.}"  # Remove trailing dot
            proxied="true"
            ;;
        MX)
            local priority=$(echo "$record" | jq -r '.ResourceRecords[0].Value | split(" ")[0]')
            content=$(echo "$record" | jq -r '.ResourceRecords[0].Value | split(" ")[1]')
            content="${content%.}"
            echo "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"priority\":$priority,\"ttl\":$ttl}"
            return
            ;;
        TXT)
            content=$(echo "$record" | jq -r '.ResourceRecords[0].Value')
            # TXT records often have quotes that need handling
            ;;
        *)
            content=$(echo "$record" | jq -r '.ResourceRecords[0].Value // .AliasTarget.DNSName // ""')
            content="${content%.}"
            ;;
    esac

    # Skip empty content
    [ -z "$content" ] && return

    echo "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"proxied\":$proxied}"
}

# Import records to Cloudflare
import_records() {
    check_prereqs

    local EXPORT_FILE="${1:-}"

    if [ -z "$EXPORT_FILE" ]; then
        echo "Available exports:"
        ls -la "$EXPORT_DIR"/*.json 2>/dev/null || echo "No exports found. Run 'export' first."
        echo ""
        read -p "Enter export file path: " EXPORT_FILE
    fi

    [ -f "$EXPORT_FILE" ] || error "File not found: $EXPORT_FILE"

    # Get zone name from filename
    ZONE_NAME=$(basename "$EXPORT_FILE" | sed 's/-route53-.*//')

    log "Importing records for $ZONE_NAME to Cloudflare..."
    log "Zone ID: $CLOUDFLARE_ZONE_ID"

    # Confirm
    read -p "This will create DNS records in Cloudflare. Continue? (y/N): " confirm
    [ "$confirm" != "y" ] && exit 0

    # Process each record
    local success=0
    local skipped=0
    local failed=0

    while IFS= read -r record; do
        local cf_record=$(convert_record "$record" "$ZONE_NAME")

        [ -z "$cf_record" ] && { ((skipped++)); continue; }

        local name=$(echo "$cf_record" | jq -r '.name')
        local type=$(echo "$cf_record" | jq -r '.type')

        info "Creating: $type $name"

        response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$cf_record")

        if echo "$response" | jq -e '.success' &>/dev/null; then
            ((success++))
        else
            warn "Failed: $name - $(echo "$response" | jq -r '.errors[0].message // "Unknown error"')"
            ((failed++))
        fi

        # Rate limiting
        sleep 0.25

    done < <(jq -c '.ResourceRecordSets[]' "$EXPORT_FILE")

    echo ""
    log "Import complete!"
    echo "  ✅ Created: $success"
    echo "  ⏭️  Skipped: $skipped (SOA/NS)"
    echo "  ❌ Failed: $failed"
}

# Verify DNS records
verify_records() {
    local domain="${1:-leopaska.xyz}"

    log "Verifying DNS for $domain..."

    echo ""
    info "Cloudflare nameservers:"
    dig NS "$domain" +short

    echo ""
    info "Sample A record resolution:"
    dig A "$domain" +short

    echo ""
    info "Testing via Cloudflare DNS (1.1.1.1):"
    dig @1.1.1.1 "$domain" +short

    echo ""
    info "Current Cloudflare records:"
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | \
        jq -r '.result[] | "\(.type)\t\(.name)\t\(.content)\t\(.proxied)"' | column -t
}

# Create Cloudflare tunnel DNS records
create_tunnel_records() {
    check_prereqs

    log "Creating Cloudflare Tunnel DNS records..."

    # Get tunnel ID from credentials
    TUNNEL_ID=$(jq -r '.TunnelID' /home/l3o/git/homelab/services/cloudflare-tunnel/credentials.json 2>/dev/null)

    if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
        error "Tunnel ID not found in credentials.json"
    fi

    TUNNEL_CNAME="${TUNNEL_ID}.cfargotunnel.com"
    log "Tunnel CNAME: $TUNNEL_CNAME"

    # Services to create DNS records for
    SERVICES=(
        "traefik"
        "argocd"
        "grafana"
        "prometheus"
        "workflow"
        "openwebui"
        "homeassistant"
        "jellyfin"
        "minio"
        "warden"
        "potluck"
        "localist"
        "blink"
        "ae"
        "authorworks"
        "trade"
        "ursulai"
        "omni"
        "hyva"
    )

    for svc in "${SERVICES[@]}"; do
        info "Creating CNAME: ${svc}.leopaska.xyz -> $TUNNEL_CNAME"

        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"${svc}\",\"content\":\"${TUNNEL_CNAME}\",\"proxied\":true}" | \
            jq -r 'if .success then "✅ Created" else "❌ \(.errors[0].message)" end'

        sleep 0.25
    done

    log "Tunnel DNS records created"
}

# Main
case "${1:-help}" in
    export)
        export_records "${2:-}"
        ;;
    import)
        import_records "${2:-}"
        ;;
    verify)
        verify_records "${2:-}"
        ;;
    tunnel-dns)
        create_tunnel_records
        ;;
    list)
        list_zones
        ;;
    *)
        echo "Route53 to Cloudflare DNS Migration"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  list          List Route53 hosted zones"
        echo "  export [id]   Export Route53 records to JSON"
        echo "  import [file] Import records to Cloudflare"
        echo "  verify [dom]  Verify DNS resolution"
        echo "  tunnel-dns    Create tunnel CNAME records"
        echo ""
        echo "Prerequisites:"
        echo "  - Set AWS profile: leo or pie"
        echo "  - Set Cloudflare context: cf-leo"
        ;;
esac
