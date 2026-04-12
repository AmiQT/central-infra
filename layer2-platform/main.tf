# Install NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-system"
  create_namespace = true

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
}

# Install Prometheus Observability Stack (including Grafana)
resource "helm_release" "prometheus" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  # Set default grafana to true so you have the sick dashboard
  set {
    name  = "grafana.enabled"
    value = "true"
  }
  
  # Make it scan for ALL ServiceMonitors across namespaces without needing strict label matching
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
}
