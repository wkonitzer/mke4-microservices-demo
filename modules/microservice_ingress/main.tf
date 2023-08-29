resource "kubernetes_ingress_v1" "microservice_ingress" {
  metadata {
    name      = var.server_name
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class" = "caddy"   
    }
  }
  spec {
    rule {
      host = "${var.server_name}.${var.domain_name}"
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend"
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