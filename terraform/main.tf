resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "8.1.3"

  create_namespace = true

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }

  set {
    name  = "server.ingress.hostname"
    value = "argocd.preview.cloud4devs.com.br"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

}

# To reuse my existing Sealed Secrets key, I need to create the namespace and the Kubernetes secrets before installing the Sealed Secrets Helm chart
resource "kubernetes_manifest" "sealed_secrets_namespace" {
  manifest   = yamldecode(file("${path.module}/sealed-secrets-namespace.yaml"))
  depends_on = [module.eks]
}

resource "kubernetes_manifest" "sealed_secrets_key" {
  manifest = yamldecode(file("${path.module}/sealed-secrets-key.yaml"))
  depends_on = [
    kubernetes_manifest.sealed_secrets_namespace
  ]
}

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  namespace  = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets/"
  chart      = "sealed-secrets"
  version    = "2.17.3"

  create_namespace = true

  set {
    name  = "secretName"
    value = "sealed-secrets-key"
  }

  depends_on = [
    kubernetes_manifest.sealed_secrets_key
  ]

}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  namespace  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.13.0"

  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value = aws_acm_certificate.preview_wildcard.arn
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"
    value = "tcp"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"
    value = "443"
  }

  set {
    name  = "controller.service.targetPorts.https"
    value = "http"
  }

  set {
    name  = "controller.service.targetPorts.http"
    value = "8080"
  }

  set {
    name  = "controller.config.http-snippet"
    value = <<-EOF
      server {
        listen 8080;
        return 308 https://$host$request_uri;
      }
    EOF


  }

  set {
    name  = "controller.config.proxy-real-ip-cidr"
    value = local.vpc_cidr
  }

  set {
    name  = "controller.config.use-forwarded-headers"
    value = "true"
  }

}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}

resource "aws_iam_role" "github_role" {
  name = "github_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:viniciuslsdias/support-portal:ref:refs/heads/*",
              "repo:viniciuslsdias/support-portal:ref:refs/tags/*",
              "repo:viniciuslsdias/support-portal:ref:refs/pull/*/merge"
            ]
          }
        }
      }
    ]
  })

}

resource "aws_iam_role_policy" "ecr_policy" {
  name = "ecr_policy"
  role = aws_iam_role.github_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:*",
        ]
        Effect   = "Allow"
        Resource = "${aws_ecr_repository.support_portal.arn}"
      },
      {
        Action = [
          "ecr:GetAuthorizationToken",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_ecr_repository" "support_portal" {
  name = "support-portal"
}

resource "aws_acm_certificate" "preview_wildcard" {
  domain_name       = "*.preview.cloud4devs.com.br"
  validation_method = "DNS"
}

data "aws_caller_identity" "current" {}

module "iam_eks_role" {
  source    = "git::https://github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-role-for-service-accounts-eks?ref=v5.59.0"
  role_name = "hook-preview-db"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  }

  oidc_providers = {
    one = {
      provider_arn               = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
      namespace_service_accounts = ["*:hook-preview-db"]
    }
  }

  assume_role_condition_test = "StringLike"
}
