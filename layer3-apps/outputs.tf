output "namespace" {
  description = "The dedicated namespace created for application workloads"
  value       = kubernetes_namespace.apps_namespace.metadata[0].name
}

output "service_account_name" {
  description = "The name of the service account created for the operations bot"
  value       = kubernetes_service_account.gopher_bot_sa.metadata[0].name
}

output "service_account_token" {
  description = "The long-lived service account token for external client authentication"
  value       = kubernetes_secret.gopher_bot_token.data["token"]
  sensitive   = true
}
