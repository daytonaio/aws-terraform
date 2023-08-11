# Prometheus server
resource "random_password" "prometheus" {
  length  = 24
  special = false
}

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  provider         = helm.my_cluster
  chart            = "prometheus"
  version          = "19.3.3"
  wait             = true
  timeout          = 300
  atomic           = true
  cleanup_on_fail  = true
  namespace        = "metrics"
  create_namespace = true

  values = [<<YAML
server:
  persistentVolume:
    storageClass: ${kubernetes_storage_class.gp2-encrypted.metadata[0].name}
  nodeSelector:
    nodegroup: metrics
alertmanager:
  persistentVolume:
    storageClass: ${kubernetes_storage_class.gp2-encrypted.metadata[0].name}
YAML
  ]

  depends_on = [ kubernetes_storage_class.gp2-encrypted ]
}

resource "helm_release" "grafana" {
  name             = "grafana"
  namespace        = "metrics"
  repository       = "https://grafana.github.io/helm-charts"
  provider         = helm.my_cluster
  chart            = "grafana"
  version          = "6.50.7"
  wait             = true
  timeout          = 300
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = true

  values = [<<YAML
nodeSelector:
  nodegroup: metrics
YAML
  ]
}
