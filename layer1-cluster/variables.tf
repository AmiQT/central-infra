variable "cluster_mode" {
  description = "Where to provision the cluster: 'k3d' (local) or 'aws-ec2' (single-node k3s on EC2). Layers 2-4 consume the same kubeconfig either way."
  type        = string
  default     = "k3d"

  validation {
    condition     = contains(["k3d", "aws-ec2"], var.cluster_mode)
    error_message = "cluster_mode must be either 'k3d' or 'aws-ec2'."
  }
}

variable "cluster_name" {
  description = "The name of the local k3d Kubernetes cluster"
  type        = string
  default     = "central-infra-lab"
}

# --- aws-ec2 mode settings (ignored in k3d mode) ---

variable "aws_region" {
  description = "AWS region for the EC2 cluster (keep consistent with layer0-bootstrap)"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "EC2 instance type. t3.large (8GB) recommended to fit the full layer2 platform stack (Prometheus + ArgoCD + NGINX)."
  type        = string
  default     = "t3.large"
}

variable "admin_cidr" {
  description = "CIDR allowed to reach the k3s API (6443) so the host can run layers 2-4. RESTRICT to your IP/32 — default is open and insecure."
  type        = string
  default     = "0.0.0.0/0"
}

variable "servers_count" {
  description = "The number of server nodes in the k3d cluster"
  type        = number
  default     = 1
}

variable "agents_count" {
  description = "The number of agent nodes in the k3d cluster"
  type        = number
  default     = 2
}

variable "host_ingress_port" {
  description = "The port mapped on the host machine to the cluster loadbalancer ingress port (80)"
  type        = number
  default     = 8080
}

variable "registry_name" {
  description = "The name of the local container registry"
  type        = string
  default     = "central-infra-registry"
}

variable "registry_port" {
  description = "The port the local container registry will listen on"
  type        = number
  default     = 5001
}

variable "api_port" {
  description = "The static port for the Kubernetes API server on the host machine"
  type        = number
  default     = 6550
}
