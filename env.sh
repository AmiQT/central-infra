#!/bin/bash
# Auto-exports KUBECONFIG for Bash/WSL/Git Bash sessions
export KUBECONFIG="$(pwd)/layer1-cluster/kubeconfig.yaml"
echo "✅ KUBECONFIG path auto-exported to: $KUBECONFIG"
