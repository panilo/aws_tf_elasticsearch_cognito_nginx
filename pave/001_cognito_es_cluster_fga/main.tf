provider "aws" {
  profile = "mycompany"
  region  = var.region
}

data "aws_kms_key" "default" {
  key_id = "alias/aws/es"
}

locals {
  tags = {
    project = "es_cognito_poc"
  }
  cognito_domain_name = "es-auth-poc"
  es_domain_name      = "es-cognito-fga-2"
}

# Create VPC, Subnets, Security Groups
module "network" {
  source = "../000_vpc_subnets_sec_groups"

  tags = local.tags
}

# COGNITO
module "cognito" {
  source = "../../modules/cognito_user_id_pools"

  domain_name = "es-auth-poc"
  name        = "es_cognito_poc"

  tags = local.tags
}

# CREATE IAM ROLE FOR ES COGNITO
resource "aws_iam_role" "es_cognito_role" {
  name = "es_cognito_poc"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "es_cognito_role_policy_attachement" {
  role       = aws_iam_role.es_cognito_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonESCognitoAccess"
}

# CREATE ES CLUSTER
# FGA
module "es_cluster" {
  source = "../../modules/es_cluster_with_cognito_and_fga"

  es_domain_name = local.es_domain_name
  subnet_ids     = module.network.subnet_ids
  security_group_ids = [
    module.network.es_sg_id
  ]

  cognito_idp_id                    = module.cognito.idp_id
  cognito_user_pool_id              = module.cognito.user_pool_id
  es_cognito_role_arn               = aws_iam_role.es_cognito_role.arn
  es_cognito_authenticated_role_arn = module.cognito.authenticated_role_arn

  ebs_encryption_kms_key_id = data.aws_kms_key.default.id

  tags = local.tags
}

# Reverse proxy
module "reverse_proxy" {
  source = "../002_reverse_proxy"

  es_domain_name      = local.es_domain_name
  cognito_domain_name = local.cognito_domain_name
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.subnet_ids
  security_group_ids = [
    module.network.es_ec2_sg_id
  ]
  region = var.region
  tags   = local.tags
}
