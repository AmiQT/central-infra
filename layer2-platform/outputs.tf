output "ingress_namespace" {
  description = "The namespace where the Ingress Controller is installed"
  value       = var.ingress_namespace
}

output "monitoring_namespace" {
  description = "The namespace where the Prometheus stack is installed"
  value       = var.monitoring_namespace
}
