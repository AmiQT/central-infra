# 1. Create a dedicated namespace for your apps
resource "kubernetes_namespace" "apps_namespace" {
  metadata {
    name = "gopher-ops"
  }
}

# 2. Service Account for Gopher-Ops Bot to talk to K8s API
resource "kubernetes_service_account" "gopher_bot_sa" {
  metadata {
    name      = "gopher-ops-bot"
    namespace = kubernetes_namespace.apps_namespace.metadata[0].name
  }
}

# 3. ClusterRole: Give it powers to 'watch' and 'list' Events, Pods, Deployments
resource "kubernetes_cluster_role" "gopher_bot_role" {
  metadata {
    name = "gopher-ops-monitor"
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

# 4. Bind the powers to the Service Account
resource "kubernetes_cluster_role_binding" "gopher_bot_binding" {
  metadata {
    name = "gopher-ops-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.gopher_bot_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.gopher_bot_sa.metadata[0].name
    namespace = kubernetes_namespace.apps_namespace.metadata[0].name
  }
}
