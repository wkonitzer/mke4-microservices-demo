terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }   
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }                  
  }
}
