variable "cloudflare_api_key" {
  description = "API key for Cloudflareprovider"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The domain name for the microservice."
  type        = string
}

