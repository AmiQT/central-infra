variable "cluster_name" {
  description = "The name of the local k3d Kubernetes cluster"
  type        = string
  default     = "central-infra-lab"
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
