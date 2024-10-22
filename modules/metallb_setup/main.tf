resource "kubectl_manifest" "ip_address_pool" {
  yaml_body = <<-YAML
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
    - "${var.lb_address_range}" 
  YAML
}

resource "kubectl_manifest" "l2_advertisement" {
  yaml_body = <<-YAML
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
  YAML
}

resource "null_resource" "metallb_dependencies" {
  depends_on = [
    kubectl_manifest.ip_address_pool,
    kubectl_manifest.l2_advertisement
  ]
}
