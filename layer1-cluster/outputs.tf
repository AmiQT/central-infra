output "cluster_name" {
  description = "The name of the provisioned k3d Kubernetes cluster"
  value       = var.cluster_name
}

output "kubeconfig_path" {
  description = "The absolute path to the generated kubeconfig file on the host system"
  value       = data.local_file.kubeconfig.filename
}

output "kubeconfig_raw" {
  description = "The raw contents of the generated kubeconfig file"
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}
