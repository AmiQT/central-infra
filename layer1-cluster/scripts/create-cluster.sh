#!/usr/bin/env bash
#
# create-cluster.sh — provision the local k3d cluster and export its kubeconfig.
# Linux/macOS-native replacement for the inline PowerShell provisioner.
#
# Called by Terraform's local-exec provisioner in main.tf. Positional args keep
# Terraform as the single source of truth for configuration (no hardcoding here).
#
# Usage:
#   create-cluster.sh <cluster_name> <api_port> <servers> <agents> \
#                     <host_ingress_port> <registry_name> <registry_port>
#
set -euo pipefail

CLUSTER_NAME="${1:?cluster_name is required}"
API_PORT="${2:?api_port is required}"
SERVERS="${3:?servers_count is required}"
AGENTS="${4:?agents_count is required}"
HOST_INGRESS_PORT="${5:?host_ingress_port is required}"
REGISTRY_NAME="${6:?registry_name is required}"
REGISTRY_PORT="${7:?registry_port is required}"

# Resolve paths relative to this script so it works regardless of caller CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_OUT="${SCRIPT_DIR}/../kubeconfig.yaml"

# Idempotency guard: the original PowerShell version would error if the cluster
# already existed. `k3d cluster get` returns non-zero when absent, so we branch.
if k3d cluster get "${CLUSTER_NAME}" >/dev/null 2>&1; then
  echo "[create-cluster] Cluster '${CLUSTER_NAME}' already exists — reusing it."
else
  echo "[create-cluster] Creating k3d cluster '${CLUSTER_NAME}'..."
  k3d cluster create "${CLUSTER_NAME}" \
    --api-port "${API_PORT}" \
    --servers "${SERVERS}" \
    --agents "${AGENTS}" \
    -p "${HOST_INGRESS_PORT}:80@loadbalancer" \
    --registry-create "${REGISTRY_NAME}:${REGISTRY_PORT}"
fi

# Dump a host-reachable kubeconfig for the downstream layers to consume.
echo "[create-cluster] Writing kubeconfig to ${KUBECONFIG_OUT}"
k3d kubeconfig get "${CLUSTER_NAME}" > "${KUBECONFIG_OUT}"

echo "[create-cluster] Done."
