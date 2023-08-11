provider "aws" {
  region = var.region
  profile = var.profile
}

data "aws_availability_zones" "available" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_route53_zone" "base" {
  name = var.base_domain
}

locals {
  cluster_name = "daytona-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}



