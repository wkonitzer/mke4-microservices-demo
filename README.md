# Microservices Demo Project

This Terraform project sets up Equinix Metal servers, installs mk4 using mkectl, configures a Kubernetes cluster and finally installs a demo microservices app, along with Mirantis MSR.

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
- **GoDaddy Credentials**: Necessary to configure DNS.
- **Equinix Metal Crendentials**: Necessary to provision the servers.
- **k0sctl**: Installs k0s.
- **mkectl**: Installs MKE4.
- **Linux tools**: awk, sed, grep.

---

## Modules

1. **Provision**:
   - Sets up Equinix resources.
2. **k0s**: 
   - Sets up k0s.
3. **MetalLB**: 
   - Configures MetalLB within the Kubernetes cluster.
4. **Caddy**:
   - Installs Caddy Server operator.
5. **External DNS**:
   - Installs External DNS operator.      
6. **MSR**:
   - Installs MSR.        
7. **Microservices Demo**:
   - Installs the microservice demo application.
8. **Microservice Ingress**: 
   - Sets up an ingress for a microservice.
   - Configures a DNS record for it.

---

## Quick Start

1. **Instakk Prerequisites**:
   ```bash
   sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mirantis/mke-docs/main/content/docs/getting-started/install.sh)"
   ```
2. **Terraform Initialization**:
   ```bash
   terraform init
   ```
3. **Terrafom Plan**:
   ```bash 
   terraform plan
   ```
4. **Terraform Apply**:
   ```bash   
   terraform apply
   ```

---

## Configuration

Several variables need to be exported via environment variables:

  * METAL_AUTH_TOKEN

Any other required variables can be set in terraform.tfvars.

The terraform.tfvars.example file has the minimum required parameters listed.  
