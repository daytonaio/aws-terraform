# Base domain wildcard certificate
resource "aws_acm_certificate" "base" {
  domain_name               = var.base_domain
  subject_alternative_names = ["*.${var.base_domain}"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "validation_base" {
  for_each = {
    for dvo in aws_acm_certificate.base.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.base.zone_id
}

resource "aws_acm_certificate_validation" "base" {
  certificate_arn = aws_acm_certificate.base.arn

  validation_record_fqdns = [for record in aws_route53_record.validation_base : record.fqdn]
}

resource "helm_release" "cert_manager" {
  provider         = helm.my_cluster
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.12.0"
  namespace        = "cert-manager"
  create_namespace = true
  atomic           = true

  values = [<<YAML
installCRDs: true
ingressShim:
  defaultIssuerName: letsencrypt-prod
  defaultIssuerKind: ClusterIssuer
  defaultIssuerGroup: cert-manager.io
YAML
  ]
}

