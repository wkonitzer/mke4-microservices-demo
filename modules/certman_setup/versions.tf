terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }   
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }              
  }
}
