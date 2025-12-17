# Homelab Capacity and Health Report
Generated: 2025-11-13 23:15:00

## System Capacity

### Memory
- **Total**: 54GB
- **Used**: 13GB (24%)
- **Available**: 41GB (76%)
- **Status**: ✅ Healthy

### Disk Storage
- **Root Partition** (`/`): 102GB / 232GB (46% used) - ✅ Healthy
- **Production SSD** (`/media/l3o/prod`): 158GB / 3.7TB (5% used) - ✅ Excellent

### CPU Usage
- **K3D Nodes**: 2-3% average CPU usage
- **Status**: ✅ Healthy

## Kubernetes Cluster (K3D)

### Nodes
- **Total Nodes**: 3
  - `k3d-alef-homelab-server-0`: ✅ Ready (control-plane)
  - `k3d-alef-homelab-agent-0`: ⚠️ NotReady (kubelet stopped posting status)
  - `k3d-alef-homelab-agent-1`: ✅ Ready

### Pod Status
- **Running**: 36 pods
- **Failed/CrashLoopBackOff**: 8 pods
- **Terminating**: 24 pods (stuck, needs cleanup)

### Issues Identified

#### 1. NotReady Node
- **Node**: `k3d-alef-homelab-agent-0`
- **Issue**: Kubelet stopped posting node status
- **Impact**: Pods scheduled on this node are stuck in Terminating state
- **Action**: Node restarted, monitoring recovery

#### 2. CrashLoopBackOff Pods
- **argocd-dex-server**: Authentication service failing
- **potluck-api-gateway**: Database connection pool timeout
- **localist-backend**: Database connection issues
- **trade-bot voice-api**: Service startup failures
- **spin-operator**: Operator crash loop

#### 3. Missing Secrets
- **cloudflared-credentials**: Secret not found in kube-system namespace
- **Impact**: Cloudflared pods cannot mount credentials

## Docker Containers

### Status
- **Running**: 42 containers
- **Not Running**: 7 containers
  - `vector-nd-leopaska`: ⚠️ Restarting (configuration issue - FIXED)
  - `ollama-proxy-leopaska`: ⚠️ Unhealthy (health check endpoint issue - FIXED)
  - 5 exited containers (authorworks services - old/exited)

### Issues Fixed
1. ✅ **Vector Configuration**: Fixed `exclude_images` → `exclude_containers`
2. ✅ **Ollama-Proxy Health Check**: Health endpoint verified working at `/api/v1/health`

## Resource Utilization Summary

### Memory
- Kubernetes nodes: ~5.3GB total (3 nodes)
- Docker containers: ~13GB total
- **Headroom**: 41GB available

### Disk
- Root: 46% used (130GB free)
- Production: 5% used (3.5TB free)
- **Status**: ✅ Excellent capacity

## Recommendations

### Immediate Actions
1. **Clean up stuck Terminating pods**:
   ```bash
   kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o json | jq -r '.items[] | select(.metadata.deletionTimestamp != null) | "\(.metadata.namespace) \(.metadata.name)"' | xargs -I {} kubectl delete pod {} --force --grace-period=0
   ```

2. **Monitor NotReady node recovery**: Check if `k3d-alef-homelab-agent-0` recovers after restart

3. **Investigate CrashLoopBackOff pods**:
   - Check database connectivity for potluck-api-gateway and localist-backend
   - Review argocd-dex-server configuration
   - Check spin-operator logs for startup issues

4. **Create missing secrets**:
   - Create `cloudflared-credentials` secret in kube-system namespace if needed

### Long-term Improvements
1. **Node Health Monitoring**: Set up alerts for NotReady nodes
2. **Pod Cleanup Automation**: Automate cleanup of stuck Terminating pods
3. **Resource Limits**: Review and optimize resource requests/limits
4. **Database Connection Pooling**: Investigate and fix database connection issues

## Overall Status

✅ **Capacity**: Excellent - Plenty of headroom
⚠️ **Health**: Some issues identified but system is operational
- 2/3 K3D nodes healthy
- 36/44 pods running successfully
- 42/49 Docker containers running

The homelab has sufficient capacity and most services are running correctly. The main issues are:
1. One K3D node in NotReady state (being addressed)
2. Several application pods in CrashLoopBackOff (likely database connectivity issues)
3. Stuck Terminating pods that need cleanup

