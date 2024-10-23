resource "helm_release" "longhorn" {
  create_namespace = true
  name       = "longhorn"
  namespace  = "longhorn-system"
  chart      = "longhorn"
  repository = "https://charts.longhorn.io"
  version    = var.chart_version

  #set {
  #  name  = "csi.kubeletRootDir"
  #  value = "/var/lib/kubelet"
  #}
}

resource "null_resource" "wait_for_ready" {
  provisioner "local-exec" {
    command = "sleep 10"
  } 
}

resource "kubectl_manifest" "longhorn_storageclass_patch" {
  yaml_body = <<-YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: longhorn-storageclass
  namespace: longhorn-system
data:
  storageclass.yaml: |
    kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: longhorn
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: driver.longhorn.io
    allowVolumeExpansion: true
    reclaimPolicy: "Delete"
    volumeBindingMode: Immediate
    parameters:
      numberOfReplicas: "1" # Changed to 1
      staleReplicaTimeout: "30"
      fromBackup: ""
      fsType: "ext4"
      dataLocality: "disabled"
      unmapMarkSnapChainRemoved: "ignored"
  YAML
}
