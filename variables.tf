# Project configuration
# required to export METAL_AUTH_TOKEN=XXXX

variable "project_id" {
  type        = string
  description = <<EOT
ID of your Project in Equinix Metal,
possible to handle as environment variable:
export TF_VAR_project_id="XXXXXXXXXXX"
EOT
}

variable "use_reserved_hardware" {
  description = "Flag to decide if reserved hardware should be used."
  type        = bool
  default     = false
}

variable "master_count" {
  default = 3
}

variable "worker_count" {
  default = 3
}

variable "metros" {
  description = "List of metros and their reserved hardware"
  type = list(object({
    metro            = string
    reserved_hardware = list(object({
      id   = string
      plan = string
    }))
  }))
}

variable "admin_password" {
  default = "orcaorcaorca"
}

variable "license_file_path" {
  description = "Path to the Docker Enterprise license file"
  type        = string
  default     = null
}

variable "email" {
  description = "The email address to be used with Ingress controllers"
  type        = string
}

variable "cloudflare_api_key" {
  description = "API key for cloudflare DNS provider"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The domain name for the cluster."
  type        = string
}

variable "cluster_name" {
  description = "Server name for the MKE LB/ingress"
  type        = string
  default     = "mke4"
}

variable "longhorn_server_name" {
  description = "Server name for the Longhorn module"
  type        = string
  default     = "mke4-longhorn"
}

variable "msr_server_name" {
  description = "Server name for the MSR module"
  type        = string
  default     = "mke4-msr"
}

variable "microservice_server_name" {
  description = "Server name for the Microservice module"
  type        = string
  default     = "mke4-microservice"
}

variable "trigger_cleanup" {
  type    = bool
  default = false
  description = "Controls whether the external-dns cleanup is triggered during destroy"
}

variable "operating_system" {
  type    = string
  default = "ubuntu_22_04"
}
