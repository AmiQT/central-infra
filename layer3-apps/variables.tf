variable "namespace" {
  description = "The dedicated namespace for application workloads"
  type        = string
  default     = "gopher-ops"
}

variable "service_account_name" {
  description = "The name of the service account for the operations bot"
  type        = string
  default     = "gopher-ops-bot"
}

variable "role_name" {
  description = "The name of the role configured for the operations bot"
  type        = string
  default     = "gopher-ops-monitor"
}
