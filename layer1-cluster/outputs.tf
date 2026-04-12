output "cluster_name" {
  description = "Name of the k3d cluster we just spun up"
  value       = "central-infra-lab"
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig to be passed to layer 2"
  value       = data.local_file.kubeconfig.content
  sensitive   = true # Jangan leak kat terminal tau!
}
