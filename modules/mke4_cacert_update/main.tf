locals {
  all_ips_list   = [for host in var.provision : host.ssh.address]
  first_host_ip  = local.all_ips_list[0]
}

resource "null_resource" "fetch_and_write_certificate" {
  provisioner "local-exec" {
    command = <<EOT
      # Fetch the second certificate from the chain
      cert=$(echo | openssl s_client -connect mke4.konitzer.dev:443 -showcerts 2>/dev/null | awk '/-----BEGIN CERTIFICATE-----/{i++} i==2,/-----END CERTIFICATE-----/' | sed '/^---$/q' | sed '$d')

      # Write the certificate to a local file
      echo "$cert" > root_ca.pem
    EOT
  }
}

data "local_file" "root_certificate_content" {
  depends_on = [null_resource.fetch_and_write_certificate]
  filename   = "root_ca.pem"
}

resource "local_file" "root_certificate" {
  depends_on = [null_resource.fetch_and_write_certificate]
  content    = data.local_file.root_certificate_content.content
  filename   = "root_ca_copy.pem"
}

resource "null_resource" "update_oidc_config" {
  count = length(local.all_ips_list)

  connection {
    type        = "ssh"
    host        = local.all_ips_list[count.index]
    user        = "root"
    private_key = file("ssh_keys/${var.cluster_name}.pem")
    timeout     = "2m"
  }

  provisioner "file" {
    source      = local_file.root_certificate.filename
    destination = "/tmp/root_ca.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "if [ -f /var/lib/k0s/oidc-config.yaml ]; then",
      "  cp /var/lib/k0s/oidc-config.yaml /var/lib/k0s/oidc-config.yaml.bak",
      "  echo '    certificateAuthority: |-' > /tmp/snippet.yaml",
      "  sed 's/^/     /' /tmp/root_ca.pem >> /tmp/snippet.yaml",
      "  awk '/certificateAuthority:/,/-----END CERTIFICATE-----/ { if (!done) { system(\"cat /tmp/snippet.yaml\"); done=1; } next } 1' /var/lib/k0s/oidc-config.yaml > /tmp/oidc-config-updated.yaml",
      "  cp /tmp/oidc-config-updated.yaml /var/lib/k0s/oidc-config.yaml",
      "  echo 'Certificate replaced successfully'",
      "  systemctl restart k0scontroller",
      "else",
      "  echo 'File does not exist, exiting'",
      "fi",
    ]
  }

  triggers = {
    certificate_content = local_file.root_certificate.content
  }

  depends_on = [local_file.root_certificate]
}

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' 's|server: .*|server: https://${var.cluster_name}.${var.domain_name}:6443|' ${path.root}/kubeconfig
        sed -i '' 's|server: .*|server: https://${var.cluster_name}.${var.domain_name}:6443|' ~/.mke/mke.kubeconf
      else
        sed -i 's|server: .*|server: https://${var.cluster_name}.${var.domain_name}:6443|' ${path.root}/kubeconfig
        sed -i 's|server: .*|server: https://${var.cluster_name}.${var.domain_name}:6443|' ~/.mke/mke.kubeconf
      fi
    EOT
  }
}

resource "null_resource" "append_ca_to_secret" {
  provisioner "local-exec" {
    command = <<EOT
      # Base64 encode the root certificate
      ca_cert=$(base64 -w 0 ${local_file.root_certificate.filename})

      # Patch the Kubernetes secret to add the ca.crt field
      kubectl --kubeconfig kubeconfig patch secret user-provided-ingress-cert \
        -n mke \
        --type=json \
        -p '[{"op": "add", "path": "/data/ca.crt", "value":"'$ca_cert'"}]'
    EOT
  }

  depends_on = [local_file.root_certificate, null_resource.update_kubeconfig]
}