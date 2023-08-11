resource "random_password" "rabbitmq_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "random_password" "rabbitmq_erlang_cookie" {
  length           = 32
  special          = false
}

#   TODO: remove when rabbit namespace is removed
resource "kubernetes_secret" "rabbitmq" {
  metadata {
    namespace = kubernetes_namespace.daytona.id
    name      = "rabbitmq"
  }

  data = {
    rabbitmq-password      = random_password.rabbitmq_password.result
    rabbitmq-erlang-cookie = random_password.rabbitmq_erlang_cookie.result
  }
}

resource "kubernetes_secret" "rabbitmq_app" {
  metadata {
    namespace = kubernetes_namespace.daytona.id
    name      = "rabbitmq-app"
  }

  data = {
    rabbitmq-password      = random_password.rabbitmq_password.result
    rabbitmq-erlang-cookie = random_password.rabbitmq_erlang_cookie.result
  }
}

resource "helm_release" "rabbitmq" {
  repository       = "https://charts.bitnami.com/bitnami"
  provider         = helm.my_cluster
  name             = "rabbitmq"
  namespace        = kubernetes_namespace.daytona.id
  chart            = "rabbitmq"
  version          = "12.0.6"
  wait             = true
  atomic           = true
  cleanup_on_fail  = true


  values = [<<YAML
global:
  storageClass: ${kubernetes_storage_class.gp2-encrypted.metadata[0].name}
replicaCount: 3
resources:
  requests:
    cpu: 500m
    memory: 256Mi
  limits:
    cpu: 2
    memory: 2Gi
metrics:
  enabled: true
clustering:
  forceBoot: true
auth:
  existingPasswordSecret: ${kubernetes_secret.rabbitmq_app.metadata[0].name}
  existingErlangSecret: ${kubernetes_secret.rabbitmq.metadata[0].name}
YAML
  ]

  depends_on = [ helm_release.aws_ebs_csi_driver ]
}
