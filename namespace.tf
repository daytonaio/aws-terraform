resource "kubernetes_namespace" "daytona" {
  metadata {
    annotations = {
      name = "daytona"
      "scheduler.alpha.kubernetes.io/node-selector"="nodegroup=app"
    }
    name = "daytona"
  }

  depends_on = [module.eks]
}

# TODO: remove
resource "kubernetes_namespace" "longhorn" {
  metadata {
    annotations = {
      name = "longhorn-system"
    }
    name = "longhorn-system"
  }

  depends_on = [module.eks]
}
