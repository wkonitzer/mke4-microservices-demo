variable "k0s_cluster_config" {
  description = "Content of the cluster configuration for mkectl."
  type        = string
}

variable "metallb_config" {
  description = "Content of the metallb config"
  type        = string
}

variable "provision" {
  description = "Module provision outputs including hosts"
  type = list(object({
    role = string
    ssh  = object({
      address  = string
      user     = string
      keyPath  = string
    })
  }))
}

variable "cluster_name" {
  default = "mke4"
}

variable "domain_name" {
  description = "The domain name for the cluster."
  type        = string
}