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
    EOF
  ]
}         