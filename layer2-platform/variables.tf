variable "nginx_ingress_chart_version" {
  description = "The pinned version of the NGINX Ingress Controller Helm chart"
  type        = string
  default     = "4.10.1"
}

variable "prometheus_stack_chart_version" {
  description = "The pinned version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "58.2.2"
}

variable "ingress_namespace" {
  description = "The namespace where the Ingress Controller will be installed"
  type        = string
  default     = "ingress-system"
}

variable "monitoring_namespace" {
  description = "The namespace where the Prometheus Observability stack will be installed"
  type        = string
  default     = "monitoring"
}

variable "grafana_admin_password" {
  description = "The explicit password for the Grafana admin user. No default is set on purpose — supply this via a .tfvars file or TF_VAR_grafana_admin_password so secrets never live in version control."
  type        = string
  sensitive   = true
}

variable "argocd_chart_version" {
  description = "The pinned version of the ArgoCD Helm chart"
  type        = string
  default     = "5.51.4"
}

variable "argo_rollouts_chart_version" {
  description = "The pinned version of the Argo Rollouts Helm chart"
  type        = string
  default     = "2.32.0"
}

