resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "8.1.3"

  create_namespace = true

  #  values = [
  #    file("values.yaml")
  #  ]
}

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  namespace  = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets/"
  chart      = "sealed-secrets"
  version    = "2.17.3"

  create_namespace = true

  #  values = [
  #    file("values.yaml")
  #  ]
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
