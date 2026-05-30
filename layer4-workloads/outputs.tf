output "ingress_url" {
  description = "The local URL to access the deployed application via NGINX Ingress Controller"
  value       = "http://talent-api.local:8080"
}

output "active_namespace" {
  description = "The namespace where the application is deployed"
  value       = data.terraform_remote_state.apps.outputs.namespace
}
