variable "cloudflare_api_key" {
  description = "API key for Cloudflareprovider"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  default = "mke4"
}

variable "trigger_cleanup" {
  type    = bool
  description = "Controls whether the external-dns cleanup is triggered during destroy"
}