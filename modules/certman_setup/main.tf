resource "kubectl_manifest" "letsencrypt_staging" {
  yaml_body = <<-YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: "${var.email}"
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx-default
  YAML
}

resource "kubectl_manifest" "letsencrypt_prod" {
  yaml_body = <<-YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: "${var.email}"
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx-default
  YAML
}

resource "null_resource" "certman_dependencies" {
  depends_on = [
    kubectl_manifest.letsencrypt_staging,
    kubectl_manifest.letsencrypt_prod
  ]
}
