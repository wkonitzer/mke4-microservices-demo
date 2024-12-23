locals {
  all_ips_list = [for host in var.provision : host.ssh.address]
  first_host_ip = [for host in var.provision : host.ssh.address][0]
  trimmed_k0s_cluster_config = join(
    "\n",
    [for line in split("\n", join(
      "\n",
      slice(
        slice(
          split("\n", var.k0s_cluster_config),
          5,
          length(split("\n", var.k0s_cluster_config))
        ),
        0,
        index(
          slice(
            split("\n", var.k0s_cluster_config),
            5,
            length(split("\n", var.k0s_cluster_config))
          ),
          "  k0s:"
        )
      )
    )) :
      // Add `port: 22` after `user: root`
      line == "      user: root" ? "${line}\n      port: 22" : replace(line, "- role: controller", "- role: controller+worker")
    ]
  )
}

resource "local_file" "mke4_config" {
  filename = "${path.root}/mke4.yaml"
  content  = <<EOT
apiVersion: mke.mirantis.com/v1alpha1
kind: MkeConfig
metadata:
  creationTimestamp: null
  name: mke
  namespace: mke
spec:
  addons:
  - chart:
      name: metallb
      repo: https://metallb.github.io/metallb
      values: |
        controller:
            tolerations:
                - key: node-role.kubernetes.io/master
                  operator: Exists
                  effect: NoSchedule
        speaker:
            frr:
                enabled: false
      version: 0.14.7
    dryRun: false
    enabled: true
    kind: chart
    name: metallb
    namespace: metallb-system
  apiServer:
    audit:
      enabled: false
      logPath: /var/lib/k0s/audit.log
      maxAge: 30
      maxBackup: 10
      maxSize: 10
    encryptionProvider: /var/lib/k0s/encryption.cfg
    eventRateLimit:
      enabled: false
    ${var.include_external_address ? "" : "externalAddress: \"${var.cluster_name}.${var.domain_name}\""}  
    requestTimeout: 1m0s
  authentication:
    expiry:
      refreshTokens: {}
    ldap:
      enabled: false
    oidc:
      enabled: false
    saml:
      enabled: false
  backup:
    enabled: true
    scheduled_backup:
      enabled: false
    storage_provider:
      external_options: {}
      in_cluster_options:
        admin_credentials_secret: minio-credentials
        enable_ui: true
      type: InCluster
  cloudProvider:
    enabled: false
  controllerManager:
    terminatedPodGCThreshold: 12500
  devicePlugins:
    nvidiaGPU:
      enabled: false
  dns:
    lameduck: {}
  etcd: {}
${chomp(local.trimmed_k0s_cluster_config)}
  ingressController:
    affinity:
      nodeAffinity: {}
    enabled: true
    enableLoadBalancer: true    
    extraArgs:
      defaultSslCertificate: mke/mke-ingress.tls
      enableSslPassthrough: false
      httpPort: 80
      httpsPort: 443
    nodePorts: {}
    ports: {}
    replicaCount: 2
  kubelet:
    eventRecordQPS: 50
    managerKubeReserved:
      cpu: 250m
      ephemeral-storage: 4Gi
      memory: 2Gi
    maxPods: 110
    podPidsLimit: -1
    podsPerCore: 0
    protectKernelDefaults: false
    seccompDefault: false
    workerKubeReserved:
      cpu: 50m
      ephemeral-storage: 500Mi
      memory: 300Mi
  monitoring:
    enableCAdvisor: false
    enableGrafana: true
    enableOpscare: false
  network:
    cplb:
      disabled: true
    kubeProxy:
      iptables:
        minSyncPeriod: 0s
        syncPeriod: 0s
      ipvs:
        minSyncPeriod: 0s
        syncPeriod: 0s
        tcpFinTimeout: 0s
        tcpTimeout: 0s
        udpTimeout: 0s
      metricsBindAddress: 0.0.0.0:10249
      mode: iptables
    nllb:
      disabled: true
    nodePortRange: 32768-35535
    providers:
    - enabled: true
      extraConfig:
        CALICO_DISABLE_FILE_LOGGING: "true"
        CALICO_STARTUP_LOGLEVEL: DEBUG
        FELIX_LOGSEVERITYSCREEN: DEBUG
        clusterCIDRIPv4: 192.168.0.0/16
        deployWithOperator: "false"
        enableWireguard: "false"
        ipAutodetectionMethod: ""
        mode: vxlan
        overlay: Always
        vxlanPort: "4789"
        vxlanVNI: "10000"
      provider: calico
    - enabled: false
      extraConfig:
        deployWithOperator: "false"
      provider: kuberouter
    - enabled: false
      extraConfig:
        deployWithOperator: "false"
      provider: custom
    serviceCIDR: 10.96.0.0/16
  policyController:
    opaGatekeeper:
      enabled: false
  scheduler: {}
  tracking:
    enabled: false
EOT

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${self.filename}"
  }
}

resource "null_resource" "remove_known_hosts" {
  provisioner "local-exec" {
    command = <<EOT
      for ip in ${join(" ", local.all_ips_list)}; do
        ssh-keygen -R $ip
      done
    EOT
  }  
}

resource "null_resource" "add_kube_apiserver_user" {
  count = length(local.all_ips_list)

  connection {
    type        = "ssh"
    host        = local.all_ips_list[count.index]
    user        = "root"
    private_key = file("ssh_keys/${var.cluster_name}.pem")
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "useradd --home /var/lib/k0s --shell /sbin/nologin --system --no-create-home kube-apiserver"
    ]
  } 
}

resource "null_resource" "sleep_before_next_step" {
  provisioner "local-exec" {
    command = "sleep 10"
  } 
}

resource "null_resource" "run_mkectl_apply" {
  depends_on = [local_file.mke4_config]

  provisioner "local-exec" {
    command = <<EOT
      if [ ! -f "${path.root}/mkectl_output.log" ]; then
        mkectl apply -f ${local_file.mke4_config.filename} -l debug 2>&1 | tee ${path.root}/mkectl_output.log && sync &
        wait
      else
        mkectl apply -f ${local_file.mke4_config.filename}
      fi
    EOT
  }

  triggers = {
    my_file_content = local_file.mke4_config.content
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.root}/mkectl_output.log"
  }
}

resource "null_resource" "wait_for_ready" {
  depends_on = [null_resource.run_mkectl_apply]
  
  provisioner "local-exec" {
    command = "sleep 30"
  } 
}



resource "null_resource" "create_creds" {
  depends_on = [null_resource.wait_for_ready]

  provisioner "local-exec" {
    command = <<EOT
      grep -o 'admin:[^ ]*' ${path.root}/mkectl_output.log > ${path.root}/creds
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.root}/creds"
  }
}

resource "null_resource" "set_kubeconfig_and_permissions" {
  depends_on = [null_resource.run_mkectl_apply]

  provisioner "local-exec" {
    command = <<EOT
      cp $HOME/.mke/mke.kubeconf ${path.root}/kubeconfig
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.root}/kubeconfig"
  }
}

resource "null_resource" "wait_for_ready2" {
  provisioner "local-exec" {
    command = "sleep 30"
  } 
}
