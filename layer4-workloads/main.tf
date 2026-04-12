# Deployment for Talent-API
resource "kubernetes_deployment" "talent_api" {
  metadata {
    name      = "talent-api"
    namespace = "default"
  }

  spec {
    replicas = 2 # SRE flex: Kita run 2 instance serentak (High Availability)

    selector {
      match_labels = {
        app = "talent-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "talent-api"
        }
      }

      spec {
        container {
          name  = "talent-api"
          # Image tebal 13GB kau tu. K3d akan sedut dari docker local cache
          image = "nginx:alpine"
          
          # Ini PENTING GILA: Never maksudnya jangan download dari internet. Guna local image yg k3d dah sedut.
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8000 # Assume fastapi jalan port 8000
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

# Service (Internal Load Balancer untuk dedahkan port Talent-API)
resource "kubernetes_service" "talent_api_svc" {
  metadata {
    name      = "talent-api-svc"
    namespace = "default"
  }

  spec {
    selector = {
      app = "talent-api"
    }

    port {
      port        = 80
      target_port = 8000
    }

    type = "ClusterIP"
  }
}
