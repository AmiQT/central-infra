# Auto-exports KUBECONFIG for PowerShell sessions
$env:KUBECONFIG = "$(Get-Location)/layer1-cluster/kubeconfig.yaml"
Write-Host "✅ KUBECONFIG path auto-exported to: $env:KUBECONFIG" -ForegroundColor Green
