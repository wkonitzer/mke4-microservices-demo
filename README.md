# MKE4 Demo Project

This Terraform project sets up Equinix Metal servers, and creates a minimal mke4.yaml file for mkectl to use. It also creates config to input for metallb.

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
- **Equinix Metal Crendentials**: Necessary to provision the servers.
- **k0sctl**: Installs k0s.
- **mkectl**: Installs MKE4.

---

## Modules

1. **Provision**:
   - Sets up Equinix resources.
2. **MKE4**: 
   - Produces mke4.yaml file

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

Any other required variables can be set in terraform.tfvars or equinix.auto.tfvars

The terraform.tfvars.example and equinix.auto.tfvars.example files have the minimum required parameters listed.  
