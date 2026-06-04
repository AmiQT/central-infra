#!/usr/bin/env bash
#
# destroy-cluster.sh — tear down the k3d cluster and remove the orphaned kubeconfig.
# Linux/macOS-native replacement for the inline PowerShell destroy provisioner.
#
# Usage:
#   destroy-cluster.sh <cluster_name>
#
set -euo pipefail

CLUSTER_NAME="${1:?cluster_name is required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_OUT="${SCRIPT_DIR}/../kubeconfig.yaml"

# Only attempt deletion if the cluster is actually present — keeps `terraform
# destroy` clean and non-fatal if the cluster was already removed out-of-band.
if k3d cluster get "${CLUSTER_NAME}" >/dev/null 2>&1; then
  echo "[destroy-cluster] Deleting cluster '${CLUSTER_NAME}'..."
  k3d cluster delete "${CLUSTER_NAME}"
else
  echo "[destroy-cluster] Cluster '${CLUSTER_NAME}' not found — nothing to delete."
fi

# Remove the generated kubeconfig if it lingers (rm -f never fails on missing).
rm -f "${KUBECONFIG_OUT}"
echo "[destroy-cluster] Cleanup complete."
