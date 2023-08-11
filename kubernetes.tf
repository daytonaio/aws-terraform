provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    command     = "aws"
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    command     = "aws"
  }
}

# TODO: k8s network policies to allow traffic between proxy service and workspace service

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.2"

  cluster_name    = local.cluster_name
  cluster_version = "1.26"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  aws_auth_accounts = [data.aws_caller_identity.current.account_id]

  //  TODO: remove
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::802408715572:user/toma.puljak"
      username = "toma.puljak"
      groups   = ["system:masters"]
    },
  ]
  
  eks_managed_node_groups = {
    app = {
      name = "node-group-app"

      ami_type = "AL2_x86_64"

      instance_types = [var.app_node_group_instance_type]

      //  TODO: parametrize
      min_size     = 1
      max_size     = 10
      desired_size = 1

      labels = {
        "nodegroup" = "app"
      }
    }

    metrics = {
      name = "node-group-metrics"

      ami_type = "AL2_x86_64"

      instance_types = [var.app_node_group_instance_type]

      //  TODO: parametrize
      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        "nodegroup" = "metrics"
      }
    }

    workload = {
      name = "node-group-workload"

      # ami_id = "ami-029171b6d43900983"
      # ami_type = "CUSTOM"
      # ami_type = "AL2_x86_64"
      ami_id = "ami-0c7cc7cb18f168151"
      # ami_id = "ami-0b306cb7e98db98e4"

      enable_bootstrap_user_data = true
      cluster_name =  module.eks.cluster_name
      cluster_endpoint = module.eks.cluster_endpoint
      cluster_auth_base64 = module.eks.cluster_certificate_authority_data

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      # cluster_service_ipv4_cidr = ""

      instance_types = [var.workload_node_group_instance_type]

      labels = {
        "sysbox-install" = "yes"
        "nodegroup" = "workload"
      }

      # taints = {
      #   workernode = {
      #     key    = "workernode"
      #     value  = "true"
      #     effect = "NO_SCHEDULE"
      #   }
      # }

      min_size     = var.workload_node_group_min_size
      max_size     = var.workload_node_group_max_size
      desired_size = var.workload_node_group_desired_size

      # longhorn requirement
      pre_bootstrap_user_data    = <<-EOT
       apt install open-iscsi -y
       systemctl start iscsid
       systemctl enable iscsid
      EOT
    }

    storage = {
      name = "node-group-storage"

      ami_type = "AL2_x86_64"

      //  additional labels for the node group
      labels = {
        "node.longhorn.io/create-default-disk" = "true"
      }

      instance_types = [var.longhorn_node_group_instance_type]

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      block_device_mappings = {
        xvdc = {
          device_name = "/dev/xvdc"
          ebs = {
            volume_size           = var.longhorn_ebs_size
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      //  no autoscaling
      min_size     = var.longhorn_node_group_size
      max_size     = var.longhorn_node_group_size
      desired_size = var.longhorn_node_group_size

      labels = {
        "nodegroup" = "longhorn",
        "node.longhorn.io/create-default-disk" = "true",
        "storage" = "longhorn"
      }

      # longhorn requirement
      pre_bootstrap_user_data    = <<-EOT
        mkdir /var/lib/longhorn -p
        mkfs.ext4 /dev/xvdc
        echo '/dev/xvdc /var/lib/longhorn ext4 defaults 0 0' >> /etc/fstab
        mount -a

        yum -y install iscsi-initiator-utils
        service iscsi start
        chkconfig iscsi on
      EOT
    }
  }
}

# Cluster autoscaling
module "cluster_autoscaler_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                        = "cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

resource "helm_release" "autoscaler" {
  repository      = "https://kubernetes.github.io/autoscaler"
  provider        = helm.my_cluster
  name            = "cluster-autoscaler"
  namespace       = "kube-system"
  chart           = "cluster-autoscaler"
  version         = "9.29.0"
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  values = [<<YAML
awsRegion: ${var.region}
rbac:
  create: true
  serviceAccount:
    name: cluster-autoscaler
    annotations:
      eks.amazonaws.com/role-arn: ${module.cluster_autoscaler_irsa_role.iam_role_arn}

autoDiscovery:
  clusterName: ${module.eks.cluster_name}
  enabled: true
YAML
  ]
}

# ALB ingress controller
module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_lb_controller" {
  repository      = "https://aws.github.io/eks-charts"
  provider        = helm.my_cluster
  name            = "aws-load-balancer-controller"
  namespace       = "kube-system"
  chart           = "aws-load-balancer-controller"
  version         = "1.4.7"
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  values = [<<YAML
clusterName: ${module.eks.cluster_name}
serviceAccount:
  create: true
  name: aws-load-balancer-controller
  annotations:
    eks.amazonaws.com/role-arn: ${module.load_balancer_controller_irsa_role.iam_role_arn}
YAML
  ]
}

# Calico network policy enforcement
resource "helm_release" "calico" {
  name             = "calico"
  repository       = "https://docs.projectcalico.org/charts"
  provider         = helm.my_cluster
  namespace        = "tigera-operator"
  chart            = "tigera-operator"
  version          = "3.25.0"
  wait             = true
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = true

  values = [<<YAML
installation:
  kubernetesProvider: EKS
YAML
  ]
}

resource "aws_security_group_rule" "calico" {
  description              = "Allow kubernetes control plane to access Calico API"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_security_group_id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5443
  to_port                  = 5443
}

# External DNS
module "external_dns_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                  = "external-dns"
  attach_external_dns_policy = true
  external_dns_hosted_zone_arns = [
    "arn:aws:route53:::hostedzone/${data.aws_route53_zone.base.zone_id}"
  ]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

resource "helm_release" "external_dns" {
  repository      = "https://charts.bitnami.com/bitnami"
  provider         = helm.my_cluster
  name            = "external-dns"
  namespace       = "kube-system"
  chart           = "external-dns"
  version         = "6.13.2"
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  values = [<<YAML
provider: aws
aws:
  zoneType: public
txtOwnerId: external-dns-${module.eks.cluster_name}
domainFilters:
  - ${var.base_domain}
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: ${module.external_dns_irsa_role.iam_role_arn}
podSecurityContext:
  fsGroup: 65534
  runAsUser: 0
policy: sync
YAML
  ]

  depends_on = [module.eks]
}
