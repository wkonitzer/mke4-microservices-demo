data "terraform_remote_state" "self" {
  backend = "local" 
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

resource "kubernetes_secret" "cloudflare_api_key" {
  depends_on = [kubernetes_namespace.external_dns]
  metadata {
    name      = "cloudflare-api-key"
    namespace = "external-dns"
  }

  data = {
    apiKey = var.cloudflare_api_key
  }

  type = "Opaque"
}

resource "helm_release" "external_dns" {
  depends_on = [kubernetes_secret.cloudflare_api_key]
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "external-dns"

  values = [
    <<-EOF
    provider:
      name: cloudflare
    env:
      - name: CF_API_TOKEN
        valueFrom:
          secretKeyRef:
            name: cloudflare-api-key
            key: apiKey
    txtPrefix: "${var.cluster_name}"
    EOF
  ]
}

resource "null_resource" "external_dns_cleanup_patch" {
  count = var.trigger_cleanup == true ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      kubectl --kubeconfig ${path.root}/kubeconfig patch deployment external-dns -n external-dns --patch '{
        "spec": {
          "template": {
            "spec": {
              "containers": [{
                "name": "external-dns",
                "args": [
                  "--source=service",
                  "--source=ingress",
                  "--provider=cloudflare",
                  "--txt-owner-id=${var.cluster_name}",
                  "--once",
                  "--cleanup"
                ]
              }]
            }
          }
        }
      }'
    EOT
  }

  depends_on = [helm_release.external_dns]
}

resource "null_resource" "wait_for_cleanup" {
  count = var.trigger_cleanup == true ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      kubectl --kubeconfig ${path.root}/kubeconfig wait --for=condition=complete --timeout=60s pod --all -n external-dns
    EOT
  }

  depends_on = [null_resource.external_dns_cleanup_patch]
}
