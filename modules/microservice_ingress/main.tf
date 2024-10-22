resource "kubernetes_ingress_v1" "microservice_ingress" {
  metadata {
    name      = var.server_name
    namespace = var.namespace
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"   
    }
  }
  spec {
    ingress_class_name = "nginx-default"

    tls {
      hosts = ["${var.server_name}.${var.domain_name}"]
      secret_name = "microservice-tls"
    }

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