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

resource "kubernetes_manifest" "longhorn_storageclass_patch" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "ConfigMap"
    "metadata" = {
      "name"      = "longhorn-storageclass"
      "namespace" = "longhorn-system"
    }
    "data" = {
      "storageclass.yaml" = <<-EOT
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
          numberOfReplicas: "1" # Updated to 1
          staleReplicaTimeout: "30"
          fromBackup: ""
          fsType: "ext4"
          dataLocality: "disabled"
          unmapMarkSnapChainRemoved: "ignored"
      EOT
    }
  }
}
