#!/bin/bash
# Update Host Service Endpoints
# Updates all K8s Endpoints labeled with host-service=true
# to point to the current node's IP address
#
# Usage: ./update-host-endpoints.sh [--dry-run]
#
set -euo pipefail

DRY_RUN="${1:-}"

# Get the current node IP (primary interface)
get_node_ip() {
  # Try to get from kubectl first
  local ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

  # Fallback to hostname command
  if [[ -z "$ip" ]]; then
    ip=$(hostname -I | awk '{print $1}')
  fi

  echo "$ip"
}

# Update endpoints for a given service
update_endpoint() {
  local namespace="$1"
  local name="$2"
  local ip="$3"
  local port="$4"
  local port_name="${5:-}"

  local endpoint_yaml=$(cat <<EOF
apiVersion: v1
kind: Endpoints
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    host-service: "true"
  annotations:
    host-ip: "${ip}"
    updated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
subsets:
  - addresses:
      - ip: ${ip}
    ports:
      - port: ${port}
        name: ${port_name:-tcp}
EOF
)

  if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo "Would apply:"
    echo "$endpoint_yaml"
    echo "---"
  else
    echo "$endpoint_yaml" | kubectl apply -f -
  fi
}

# Main
echo "=== Updating Host Service Endpoints ==="
NODE_IP=$(get_node_ip)
echo "Node IP: $NODE_IP"

if [[ -z "$NODE_IP" ]]; then
  echo "ERROR: Could not determine node IP"
  exit 1
fi

echo ""
echo "Updating endpoints..."

# PostgreSQL
update_endpoint "databases" "host-postgres" "$NODE_IP" "5432" "postgres"

# Ollama
update_endpoint "ai" "host-ollama" "$NODE_IP" "11434" "ollama"

# Node Exporter
update_endpoint "monitoring" "host-node-exporter" "$NODE_IP" "9100" "metrics"

# Also update neon-postgres for backward compatibility
update_endpoint "databases" "neon-postgres" "$NODE_IP" "5432" "postgres"

echo ""
echo "=== Done ==="
echo "All host-service endpoints updated to point to $NODE_IP"
