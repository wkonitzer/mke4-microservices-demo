resource "kubernetes_ingress_v1" "msr_ingress" {
  metadata {
    name      = "msr-ingress"
    namespace = "msr"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }
  spec {
    ingress_class_name = "nginx-default"

    tls {
      hosts = ["${var.server_name}.${var.domain_name}"]
      secret_name = "msr-tls"
    }  
    rule {
      host = "${var.server_name}.${var.domain_name}"
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "msr"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
}