variable "replica_count" {
  description = "Number of pod replicas to deploy"
  type        = number
  default     = 2
}

variable "app_name" {
  description = "Name of the target workload application"
  type        = string
  default     = "talent-api"
}

variable "container_port" {
  description = "Port the container application listens on (e.g. 80 for nginx, 8000 for fastapi)"
  type        = number
  default     = 80
}
