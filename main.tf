module "provision" {
  source             = "github.com/wkonitzer/k0s-on-equinix-terraform-templates"
  project_id         = var.project_id
  cluster_name       = var.cluster_name
  master_count       = var.master_count
  worker_count       = var.worker_count
  metros             = var.metros
  operating_system   = var.operating_system
  machine_size       = var.machine_size
}

module "mke4" {
  depends_on         = [module.provision]
  source             = "./modules/mke4"
  k0s_cluster_config = module.provision.k0s_cluster
  provision          = module.provision.hosts
  cluster_name       = var.cluster_name
  metallb_config     = module.provision.metallb_l2
  domain_name        = var.domain_name
}

provider "kubernetes" {
  config_path        = "${path.root}/kubeconfig"
}

provider "helm" {
  kubernetes {
    config_path      = "${path.root}/kubeconfig"
  }
}

provider "kubectl" {
  config_path        = "${path.root}/kubeconfig"
  load_config_file   = true
}

module "certman" {
  source             = "./modules/certman_setup"
  depends_on         = [module.mke4]
  email              = var.email
}

module "metallb" {
  source             = "./modules/metallb_setup"
  depends_on         = [module.mke4]
  lb_address_range   = module.provision.lb_address_range
}

module "external_dns" {
  depends_on         = [module.mke4]
  source             = "./modules/external_dns"
  cloudflare_api_key = var.cloudflare_api_key
  cluster_name       = var.cluster_name
  trigger_cleanup    = var.trigger_cleanup
}

module "longhorn" {
  depends_on         = [module.mke4, module.metallb, module.external_dns, module.certman]
  source             = "./modules/longhorn" 
  provision          = module.provision.hosts
  domain_name        = var.domain_name
  server_name        = var.longhorn_server_name
  admin_username     = "admin"
  admin_password     = var.admin_password
  #host = module.mke4.first_manager_ip
}

module "msr" {
  depends_on         = [module.longhorn, module.external_dns]
  source             = "./modules/msr" 
  domain_name        = var.domain_name
  server_name        = var.msr_server_name
  license_file_path  = var.license_file_path
}

module "gcp_microservices_demo" {
  source             = "./modules/gcp_microservices_demo"
  depends_on         = [module.mke4]
}

module "microservice_ingress" {
  source             = "./modules/microservice_ingress"
  depends_on         = [module.gcp_microservices_demo, module.external_dns]
  namespace          = module.gcp_microservices_demo.created_namespace
  domain_name        = var.domain_name
  server_name        = var.microservice_server_name
}
