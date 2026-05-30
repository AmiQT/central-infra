resource "null_resource" "k3d_cluster" {
  # Trigger if cluster name changes
  triggers = {
    cluster_name = var.cluster_name
  }

  # Create the k3d cluster and dump the kubeconfig to a file inside layer1-cluster/
  # Adds --registry-create to natively spin up a local container registry associated with the cluster!
  # Adds --api-port to guarantee a static, deterministic Kubernetes API server port on the host!
  provisioner "local-exec" {
    command     = "k3d cluster create ${self.triggers.cluster_name} --api-port ${var.api_port} --servers ${var.servers_count} --agents ${var.agents_count} -p \"${var.host_ingress_port}:80@loadbalancer\" --registry-create ${var.registry_name}:${var.registry_port} ; k3d kubeconfig get ${self.triggers.cluster_name} | Out-File -FilePath ${path.module}/kubeconfig.yaml -Encoding utf8"
    interpreter = ["PowerShell", "-Command"]
  }

  # Clean up the cluster when running 'terraform destroy' and auto-delete orphaned kubeconfig.yaml
  provisioner "local-exec" {
    when        = destroy
    command     = "k3d cluster delete ${self.triggers.cluster_name} ; if (Test-Path ${path.module}/kubeconfig.yaml) { Remove-Item -Path ${path.module}/kubeconfig.yaml -Force }"
    interpreter = ["PowerShell", "-Command"]
  }
}

# Read the generated kubeconfig so we can output it securely
data "local_file" "kubeconfig" {
  depends_on = [null_resource.k3d_cluster]
  filename   = "${path.module}/kubeconfig.yaml"
}
