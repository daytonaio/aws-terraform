module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "daytona-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  database_subnets     = ["10.0.100.0/23", "10.0.102.0/23", "10.0.104.0/23"]
  intra_subnets        = ["10.0.200.0/23", "10.0.202.0/23", "10.0.204.0/23"]
  
  # TODO: remove
  elasticache_subnets  = ["10.0.110.0/23", "10.0.112.0/23", "10.0.114.0/23"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }

  database_subnet_tags = {
    "database" = true
    "Tier"     = "Database"
  }

  elasticache_subnet_tags = {
    "Tier"     = "Elasticache"
  }
}

resource "aws_security_group" "database" {
  name        = "database_security_group"
  description = "Allow only connections from private subnets"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow access to RDS postgres from private subnet only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
}

