# 1. Create a dedicated namespace for your apps
resource "kubernetes_namespace" "apps_namespace" {
  metadata {
    name = var.namespace
  }
}

# 2. Service Account for Gopher-Ops Bot to talk to K8s API
resource "kubernetes_service_account" "gopher_bot_sa" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.apps_namespace.metadata[0].name
  }
}

# 2b. Modern Kubernetes (1.24+) Long-lived SA Token Secret!
# Ensures a secure, long-lived token secret is explicitly generated and associated with the ServiceAccount
resource "kubernetes_secret" "gopher_bot_token" {
  metadata {
    name      = "${var.service_account_name}-token"
    namespace = kubernetes_namespace.apps_namespace.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.gopher_bot_sa.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

# 3. Role: Give it powers to 'watch' and 'list' Events, Pods, Deployments INSIDE the namespace (Least Privilege Principle)
resource "kubernetes_role" "gopher_bot_role" {
  metadata {
    name      = var.role_name
    namespace = kubernetes_namespace.apps_namespace.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "events"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }
}

# 4. Bind the powers to the Service Account inside the namespace
resource "kubernetes_role_binding" "gopher_bot_binding" {
  metadata {
    name      = "${var.service_account_name}-binding"
    namespace = kubernetes_namespace.apps_namespace.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.gopher_bot_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.gopher_bot_sa.metadata[0].name
    namespace = kubernetes_namespace.apps_namespace.metadata[0].name
  }
}
