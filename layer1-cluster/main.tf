resource "null_resource" "k3d_cluster" {
  # Trigger if cluster name changes
  triggers = {
    cluster_name = "central-infra-lab"
  }

  # Create the k3d cluster and dump the kubeconfig to a file inside layer1-cluster/
  provisioner "local-exec" {
    command = "k3d cluster create ${self.triggers.cluster_name} --servers 1 --agents 2 -p \"8080:80@loadbalancer\" ; k3d kubeconfig get ${self.triggers.cluster_name} | Out-File -FilePath ${path.module}/kubeconfig.yaml -Encoding utf8"
    interpreter = ["PowerShell", "-Command"]
  }

  # Clean up the cluster when running 'terraform destroy'
  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name}"
    interpreter = ["PowerShell", "-Command"]
  }
}

# Read the generated kubeconfig so we can output it securely
data "local_file" "kubeconfig" {
  depends_on = [null_resource.k3d_cluster]
  filename   = "${path.module}/kubeconfig.yaml"
}
