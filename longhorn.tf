resource "helm_release" "longhorn" {
  provider          = helm.my_cluster
  name              = "longhorn"
  repository        = "https://charts.longhorn.io"
  chart             = "longhorn"
  version           = "1.4.2"
  namespace         = kubernetes_namespace.longhorn.id
  timeout           = 600

  values = [
    <<EOF
defaultSettings:
  createDefaultDiskLabeledNodes: true
  deletingConfirmationFlag: ${ var.allow_longhorn_remove }
longhornManager:
  tolerations:
    - key: "workernode"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
longhornDriver:
  tolerations:
    - key: "workernode"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
  EOF
  ]
}