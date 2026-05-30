# Read namespace and RBAC outputs from the Layer 3 remote state to keep a single
# source of truth and avoid inter-layer parameter drift.
data "terraform_remote_state" "apps" {
  backend = "local"

  config = {
    path = "${path.module}/../layer3-apps/terraform.tfstate"
  }
}

# Progressive delivery workload orchestration using Argo Rollouts
resource "kubernetes_manifest" "talent_api_rollout" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Rollout"
    metadata = {
      name      = var.app_name
      namespace = data.terraform_remote_state.apps.outputs.namespace
    }
    spec = {
      replicas             = var.replica_count
      revisionHistoryLimit = 3
      selector = {
        matchLabels = {
          app = var.app_name
        }
      }
      strategy = {
        canary = {
          canaryService = "talent-api-canary-svc"
          stableService = "talent-api-stable-svc"
          trafficRouting = {
            nginx = {
              stableIngress = "talent-api-ingress"
            }
          }
          steps = [
            { setWeight = 10 },
            { duration = "1m" },
            { setWeight = 50 },
            { duration = "2m" },
            {
              analysis = {
                templates = [
                  { templateName = "canary-error-rate-analysis" }
                ]
                args = [
                  { name = "service-name", value = "talent-api-canary-svc" }
                ]
              }
            }
          ]
        }
      }
      template = {
        metadata = {
          labels = {
            app = var.app_name
          }
        }
        spec = {
          serviceAccountName = data.terraform_remote_state.apps.outputs.service_account_name
          containers = [
            {
              name            = var.app_name
              image           = "nginx:alpine"
              imagePullPolicy = "IfNotPresent"
              ports = [
                {
                  containerPort = var.container_port
                  name          = "http"
                }
              ]
              lifecycle = {
                preStop = {
                  exec = {
                    command = ["/bin/sh", "-c", "sleep 10"]
                  }
                }
              }
              livenessProbe = {
                httpGet = {
                  path = "/"
                  port = var.container_port
                }
                initialDelaySeconds = 5
                periodSeconds       = 10
                timeoutSeconds      = 2
              }
              readinessProbe = {
                httpGet = {
                  path = "/"
                  port = var.container_port
                }
                initialDelaySeconds = 5
                periodSeconds       = 5
                timeoutSeconds      = 2
              }
              securityContext = {
                allowPrivilegeEscalation = false
                capabilities = {
                  drop = ["ALL"]
                  add  = ["NET_BIND_SERVICE", "CHOWN", "SETGID", "SETUID"]
                }
              }
              resources = {
                limits = {
                  memory = "512Mi"
                }
                requests = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
              }
            }
          ]
        }
      }
    }
  }
}

# Stable internal service endpoint for routed ingress traffic
resource "kubernetes_service" "talent_api_stable_svc" {
  metadata {
    name      = "talent-api-stable-svc"
    namespace = data.terraform_remote_state.apps.outputs.namespace
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      name        = "http"
      port        = 80
      target_port = var.container_port
    }

    type = "ClusterIP"
  }
}

# Canary internal service endpoint for active traffic progressive weight shifting
resource "kubernetes_service" "talent_api_canary_svc" {
  metadata {
    name      = "talent-api-canary-svc"
    namespace = data.terraform_remote_state.apps.outputs.namespace
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      name        = "http"
      port        = 80
      target_port = var.container_port
    }

    type = "ClusterIP"
  }
}

# Managed NGINX Ingress Controller interface handling external cluster boundary traffic
resource "kubernetes_ingress_v1" "talent_api_ingress" {
  metadata {
    name      = "talent-api-ingress"
    namespace = data.terraform_remote_state.apps.outputs.namespace
    annotations = {
      "kubernetes.io/ingress.class"                   = "nginx"
      "nginx.ingress.kubernetes.io/ssl-redirect"      = "false"
      "nginx.ingress.kubernetes.io/limit-connections" = "10"
      "nginx.ingress.kubernetes.io/limit-rps"         = "5"
    }
  }

  spec {
    rule {
      host = "talent-api.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.talent_api_stable_svc.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# Prometheus validation telemetry metrics automated rollback analysis template configuration
resource "kubernetes_manifest" "canary_error_rate_analysis" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AnalysisTemplate"
    metadata = {
      name      = "canary-error-rate-analysis"
      namespace = data.terraform_remote_state.apps.outputs.namespace
    }
    spec = {
      args = [
        { name = "service-name" }
      ]
      metrics = [
        {
          name             = "success-rate"
          interval         = "30s"
          successCondition = "result[0] <= 0.01"
          failureLimit     = 1
          provider = {
            prometheus = {
              address = "http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
              query   = "sum(rate(nginx_ingress_controller_requests{status=~\"5..\", service=\"{{args.service-name}}\"}[1m])) / (sum(rate(nginx_ingress_controller_requests{service=\"{{args.service-name}}\"}[1m])) + 0.001)"
            }
          }
        }
      ]
    }
  }
}

# Declarative GitOps Application manifest binding physical state directory sync to local cluster
resource "kubernetes_manifest" "argocd_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "central-infra-workloads"
      namespace = "argocd"
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/AmiQT/central-infra.git"
        targetRevision = "HEAD"
        path           = "layer4-workloads"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = data.terraform_remote_state.apps.outputs.namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}

# ServiceMonitor metrics telemetry scraper targeting workloads
resource "kubernetes_manifest" "talent_api_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "${var.app_name}-monitor"
      namespace = data.terraform_remote_state.apps.outputs.namespace
      labels = {
        release = "monitoring"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = var.app_name
        }
      }
      endpoints = [
        {
          port     = "http"
          interval = "15s"
          path     = "/metrics"
        }
      ]
    }
  }
}

