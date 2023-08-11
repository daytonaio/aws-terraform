terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.57.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.4"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2.0"
    }

    template = {
      source = "hashicorp/template"
      version = "2.2.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    kubectl = {
      source = "gavinbunney/kubectl"
    }
    
    helm = {
      source = "hashicorp/helm"
    }
  }

  required_version = "~> 1.3"
}

