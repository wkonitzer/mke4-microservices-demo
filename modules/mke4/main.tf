locals {
  all_ips_list = [for host in var.provision : host.ssh.address]
  first_host_ip = [for host in var.provision : host.ssh.address][0]
}

locals {
  all_ips_list = [for host in var.provision : host.ssh.address]
  first_host_ip = [for host in var.provision : host.ssh.address][0]
}

resource "local_file" "mke4_config" {
  filename = "${path.root}/mke4.yaml"
  content  = <<EOT
${chomp(join("\n", slice(split("\n", var.k0s_cluster_config), 5, length(split("\n", var.k0s_cluster_config)))))
}

hardening:
  enabled: true
authentication:
  enabled: true
  saml:
    enabled: false
  oidc:
    enabled: false
  ldap:
    enabled: false
backup:
  enabled: true
  storage_provider:
    type: InCluster
    in_cluster_options:
      exposed: true
tracking:
  enabled: true
trust:
  enabled: true
logging:
  enabled: true
audit:
  enabled: true
license:
  refresh: true
apiServer:
  externalAddress: "${local.first_host_ip}"
  sans: []
ingressController:
  enabled: true
  replicaCount: 2
  extraArgs:
    httpPort: 80
    httpsPort: 443
    enableSslPassthrough: false
    defaultSslCertificate: mke/auth-https.tls
monitoring:
  enableGrafana: true
  enableOpscare: false
network:
  serviceCIDR: 10.96.0.0/16
  nodePortRange: 32768-35535
  kubeProxy:
    disabled: false
    mode: iptables
    metricsbindaddress: 0.0.0.0:10249
    iptables:
      masqueradebit: null
      masqueradeall: false
      localhostnodeports: null
      syncperiod:
        duration: 0s
      minsyncperiod:
        duration: 0s
    ipvs:
      syncperiod:
        duration: 0s
      minsyncperiod:
        duration: 0s
      scheduler: ""
      excludecidrs: []
      strictarp: false
      tcptimeout:
        duration: 0s
      tcpfintimeout:
        duration: 0s
      udptimeout:
        duration: 0s
    nodeportaddresses: []
  nllb:
    disabled: true
  cplb:
    disabled: true
  providers:
  - provider: calico
    enabled: true
    CALICO_DISABLE_FILE_LOGGING: true
    CALICO_STARTUP_LOGLEVEL: DEBUG
    FELIX_LOGSEVERITYSCREEN: DEBUG
    clusterCIDRIPv4: 192.168.0.0/16
    deployWithOperator: false
    enableWireguard: false
    ipAutodetectionMethod: null
    mode: vxlan
    overlay: Always
    vxlanPort: 4789
    vxlanVNI: 10000
    windowsNodes: false
  - provider: kuberouter
    enabled: false
    deployWithOperator: false
  - provider: custom
    enabled: false
    deployWithOperator: false
EOT

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${self.filename}"
  }
}

#resource "null_resource" "remove_known_hosts" {
#  provisioner "local-exec" {
#    command = <<EOT
#      for ip in ${join(" ", local.all_ips_list)}; do
#        ssh-keygen -R $ip
#      done
#    EOT
#  }
#}

resource "null_resource" "run_mkectl_apply" {
  depends_on = [local_file.mke4_config]

  provisioner "local-exec" {
    command = <<EOT
      mkectl apply -f ${local_file.mke4_config.filename}
      sleep 70
    EOT  
  }

  triggers = {
    my_file_content = local_file.mke4_config.content
  }
}

#resource "null_resource" "set_kubeconfig_and_permissions" {
#  depends_on = [null_resource.run_k0sctl_apply]
#
#  provisioner "local-exec" {
#    command = <<EOT
#      k0sctl kubeconfig > ${path.root}/kubeconfig
#    EOT
#  }
#
#  provisioner "local-exec" {
#    when    = destroy
#    command = "rm -f ${path.root}/kubeconfig"
#  }
#}