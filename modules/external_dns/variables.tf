variable "cloudflare_api_key" {
  description = "API key for Cloudflareprovider"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  default = "mke4"
}

