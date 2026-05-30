# Install NGINX Ingress Controller (Modular & Pinned with Observability Enabled)
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.nginx_ingress_chart_version # Pinned chart version for stability
  namespace        = var.ingress_namespace
  create_namespace = true

  # Allow extra time and clean up on failure to avoid a stuck deployment
  timeout         = 600
  cleanup_on_fail = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Config to handle standard local routing for K3D
  set {
    name  = "controller.config.compute-full-forwarded-for"
    value = "true"
  }
  set {
    name  = "controller.config.use-forwarded-headers"
    value = "true"
  }

  # Enable the Prometheus metrics exporter for the NGINX Ingress Controller
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  # Auto-provision ServiceMonitor CRD so Prometheus Operator automatically scrapes Ingress metrics
  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.namespace"
    value = var.monitoring_namespace # Deploy ServiceMonitor in monitoring namespace
  }

  set {
    name  = "controller.metrics.serviceMonitor.additionalLabels.release"
    value = "monitoring" # Sync dynamically with Prometheus Stack release name
  }
}

# Install Prometheus Observability Stack (including Grafana) (Modular & Pinned)
resource "helm_release" "prometheus" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_stack_chart_version # Pinned chart version for stability
  namespace        = var.monitoring_namespace
  create_namespace = true

  # The Prometheus stack is heavy, so allow a 10-minute timeout and clean up on failure
  timeout         = 600
  cleanup_on_fail = true

  # Enable the bundled Grafana dashboards
  set {
    name  = "grafana.enabled"
    value = "true"
  }

  # Set the Grafana admin password from a sensitive, externally-supplied variable
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # Make it scan for ALL ServiceMonitors across namespaces without needing strict label matching
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # Pin resource requests and limits so the Prometheus stack stays within a modest
  # footprint on a local development machine (under ~512Mi total).
  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = "512Mi"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "grafana.resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "grafana.resources.limits.memory"
    value = "128Mi"
  }
}

# Install ArgoCD (Resource-Optimized for Local 16GB RAM Sandbox)
resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600
  cleanup_on_fail  = true

  # SRE Local Optimization: Disable unused heavy components to save RAM
  set {
    name  = "dex.enabled"
    value = "false"
  }
  set {
    name  = "notifications.enabled"
    value = "false"
  }
  set {
    name  = "applicationSet.enabled"
    value = "false"
  }

  # Constrain memory usage to keep the footprint small on a local machine
  set {
    name  = "controller.resources.limits.memory"
    value = "256Mi"
  }
  set {
    name  = "server.resources.limits.memory"
    value = "128Mi"
  }
  set {
    name  = "repoServer.resources.limits.memory"
    value = "128Mi"
  }
  set {
    name  = "redis.resources.limits.memory"
    value = "64Mi"
  }

  # Sandbox local insecure mode for HTTP local routing
  set {
    name  = "configs.params.server.insecure"
    value = "true"
  }
}

# Install Argo Rollouts Controller
resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = var.argo_rollouts_chart_version
  namespace        = "argo-rollouts"
  create_namespace = true
  timeout          = 600
  cleanup_on_fail  = true

  # Constrain resource usage to keep the footprint small on a local machine
  set {
    name  = "controller.resources.limits.memory"
    value = "128Mi"
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "50m"
  }
}

