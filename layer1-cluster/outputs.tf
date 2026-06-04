output "cluster_mode" {
  description = "Which backend provisioned the cluster"
  value       = var.cluster_mode
}

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

# --- aws-ec2 mode outputs (null in k3d mode) ---

output "cluster_public_ip" {
  description = "Elastic IP of the EC2 k3s node (aws-ec2 mode only)"
  value       = try(aws_eip.k3s[0].public_ip, null)
}

output "app_url" {
  description = "URL to reach the deployed app via the node (aws-ec2 mode only)"
  value       = try("http://${aws_eip.k3s[0].public_ip}/", "k3d local cluster")
}

output "ssm_session_command" {
  description = "Keyless shell into the node (no SSH) — requires the AWS CLI Session Manager plugin"
  value       = try("aws ssm start-session --target ${aws_instance.k3s[0].id} --region ${var.aws_region}", "n/a in k3d mode")
}
