module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "= 1.22.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn


  enable_aws_load_balancer_controller = true

  aws_load_balancer_controller = {
    set = [
      {
        name  = "replicaCount"
        value = 1
      },
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      }
    ]
  }

  tags = local.tags
}
