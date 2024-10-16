module "provision" {
  source = "github.com/wkonitzer/k0s-on-equinix-terraform-templates"
  project_id   = var.project_id
  cluster_name = var.cluster_name
  master_count = var.master_count
  worker_count = var.worker_count
  metros       = var.metros
}

module "mke4" {
  depends_on = [module.provision]
  source             = "./modules/mke4"
  k0s_cluster_config = module.provision.k0s_cluster
  provision = module.provision.hosts
  cluster_name = var.cluster_name
}

#provider "kubernetes" {
#  config_path = "${path.root}/kubeconfig"
#}

#provider "helm" {
#  kubernetes {
#    config_path = "${path.root}/kubeconfig"
#  }
#}

#provider "kubectl" {
#  config_path = "${path.root}/kubeconfig"
#  load_config_file       = true
#}

