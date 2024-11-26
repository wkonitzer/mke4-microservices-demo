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