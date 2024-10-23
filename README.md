# Microservices Demo Project

This Terraform project sets up Equinix Metal servers, installs mk4 using mkectl, configures a Kubernetes cluster and finally installs a demo microservices app, Longhorn for storage, extgernal-DNS and Mirantis MSR 3.1.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Modules](#modules)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Known Issues](#known-issues)

---

## Prerequisites

- **Terraform**: Version v1.x.x or above.
- **Kubectl Toolchain**: Ensure you have a configured kubectl toolchain.
- **Cloudflare Credentials**: Necessary to configure DNS.
- **Equinix Metal Crendentials**: Necessary to provision the servers.
- **k0sctl**: Installs k0s.
- **mkectl**: Installs MKE4.

---

## Modules

1. **Provision**:
   - Sets up Equinix resources.
2. **MKE4**: 
   - Sets up MKE4.
3. **Cert-Manager**: 
   - Configures Cert-manager within the cluster for letsencrypt. 
4. **MetalLB**: 
   - Configures MetalLB within the Kubernetes cluster.     
5. **External DNS**:
   - Installs External DNS operator.
6. **Longhorn**:
   - Installs Longhorn Storage.     
7. **MSR**:
   - Installs MSR.        
8. **Microservices Demo**:
   - Installs the microservice demo application.
9. **Microservice Ingress**: 
   - Sets up an ingress for a microservice.
   - Configures a DNS record for it.

---

## Quick Start

1. **Install Prerequisites**:
   ```bash
   sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mirantis/mke-docs/main/content/docs/getting-started/install.sh)"
   ```
2. **Terraform Initialization**:
   ```bash
   terraform init
   ```
3. **Terrafom Plan Infrastructure**:
   ```bash 
   terraform plan -target=module.mke4
   ```
4. **Terraform Apply Infrastructure**:
   ```bash   
   terraform apply
   ```
5. **Terrafom Plan (everything else)**:
   ```bash 
   terraform plan
   ```
6. **Terraform Apply (everything else)**:
   ```bash   
   terraform apply
   ```

---

## Configuration

Several variables need to be exported via environment variables:

  * METAL_AUTH_TOKEN

Any other required variables can be set in terraform.tfvars or equinix.auto.tfvars

The terraform.tfvars.example and equinix.auto.tfvars.example files have the minimum required parameters listed.  

--

## Known Issues

To destroy run
```bash
terraform state rm module.longhorn.module.longhorn.helm_release.longhorn
terraform destroy -var="trigger_cleanup=true"
```
