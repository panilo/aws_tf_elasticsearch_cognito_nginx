provider "aws" {
  profile = "mycompany"
  region  = var.region
}

# GET REGION
data "aws_region" "current" {}

locals {
  tags = {
    project = "es_cognito_poc"
  }
  cognito_domain_name = "es-auth-poc"
}


# Create VPC, Subnets, Security Groups
module "network" {
  source = "../000_vpc_subnets_sec_groups"
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
# NO FGA
module "es_cluster" {
  source = "./modules/es_cluster_with_cognito"

  es_domain_name = "es-cognito-poc-open-distro"
  subnet_ids     = module.network.subnet_ids
  security_group_ids = [
    module.network.es_sg_id
  ]

  cognito_idp_id                    = module.cognito.idp_id
  cognito_user_pool_id              = module.cognito.user_pool_id
  es_cognito_role_arn               = aws_iam_role.es_cognito_role.arn
  es_cognito_authenticated_role_arn = module.cognito.authenticated_role_arn

  tags = local.tags
}

# CREATE A SELF SIGNED CERTIFICATE TO BE USED IN THE ALB
module "ssc" {
  source = "./modules/self_sign_acm_certificate"

  domain_name = "es-cognito-poc.com"

  tags = local.tags
}

# CREATE AN ALB
module "alb" {
  source = "./modules/elb"

  name = "es-cognito-poc"

  vpc_id     = module.vpc.id
  subnet_ids = module.network.subnet_ids
  security_group_ids = [
    module.network.es_ec2_sg_id
  ]

  certificate_arn = module.ssc.arn

  tags = local.tags
}

# CREATE AN ASG FOR THE NGINX CLUSTER
data "aws_ami" "default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "template_file" "bootstrap" {
  template = file("${path.module}/nginx.conf")

  vars = {
    es-cluster-endpoint = module.es_cluster.endpoint
    cognito_host        = "${local.cognito_domain_name}.auth.${data.aws_region.current.name}.amazoncognito.com"
  }
}

resource "aws_s3_bucket" "config_bucket" {
  bucket = "es-cognito-poc-bucket"
  acl    = "private"

  tags = local.tags
}

resource "aws_s3_bucket_object" "object" {
  bucket  = aws_s3_bucket.config_bucket.bucket
  key     = "nginx.conf"
  content = data.template_file.bootstrap.rendered

  etag = md5(data.template_file.bootstrap.rendered)
}

resource "aws_iam_role" "ec2" {
  name = "es_cognito_poc_ec2"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachement" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "profile" {
  name = "es_cognito_poc"
  role = aws_iam_role.ec2.name
}

module "asg-nginx" {
  source = "./modules/asg"

  name = "es_cognito_poc"

  asg_min       = 1
  asg_max       = 3
  asg_desidered = 2

  subnet_ids = module.network.subnet_ids

  instances_template = {
    prefix        = "es_cognito_poc",
    ami-id        = data.aws_ami.default.image_id,
    instance-type = "t2.micro",
    iam-profile   = aws_iam_instance_profile.profile.name
    security-groups = [
      module.network.es_ec2_sg_id
    ],
    user-data        = file("${path.module}/bootstrap.sh"),
    root-volume-size = 30
  }

  lb_target_group_arns = [
    module.alb.target_group_arn
  ]

  tags = local.tags
}
