# EBS CSI driver
module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "helm_release" "aws_ebs_csi_driver" {
  repository      = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  provider        = helm.my_cluster
  name            = "aws-ebs-csi-driver"
  namespace       = "kube-system"
  chart           = "aws-ebs-csi-driver"
  version         = "2.16.0"
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  values = [<<YAML
controller:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: ${module.ebs_csi_irsa_role.iam_role_arn}
YAML
  ]
}

# Encrypted Storage Class
resource "kubernetes_storage_class" "gp2-encrypted" {
  metadata {
    name = "gp2-encrypted"
    annotations = {
      "provisioner" = "terraform.io"
    }
  }
  parameters = {
    type      = "gp2"
    encrypted = true
    fsType    = "ext4"
  }
  volume_binding_mode = "WaitForFirstConsumer"
  storage_provisioner = "kubernetes.io/aws-ebs"

  depends_on = [ helm_release.aws_ebs_csi_driver ]
}