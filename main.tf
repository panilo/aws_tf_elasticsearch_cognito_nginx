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

# CREATE VPC
module "vpc" {
  source = "./modules/vpc"

  name       = "es_cognito_poc_vpc"
  cidr_block = "10.0.0.0/16"
  tags       = local.tags
}

# CREATE ONE SUBNET FOR AZ
module "subnet" {
  source = "./modules/subnet"

  name       = "es_cognito_poc_sn"
  vpc_id     = module.vpc.id
  cidr_block = "10.0.X.0/24"
  tags       = local.tags
}

output "subnet_ids" {
  value = module.subnet.created.*.id
}

# COGNITO USER POOL
resource "aws_cognito_user_pool" "pool" {
  name = "es_cognito_poc"

  admin_create_user_config {
    allow_admin_create_user_only = true

    invite_message_template {
      email_message = "Your username is {username} and temporary password is {####}. "
      email_subject = "Your temporary password"
      sms_message   = "Your username is {username} and temporary password is {####}. "
    }
  }

  auto_verified_attributes = ["email"]

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 3
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true
    string_attribute_constraints {
      max_length = "2048"
      min_length = "0"
    }
  }

  username_configuration {
    case_sensitive = false
  }

  tags = local.tags
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = local.cognito_domain_name
  user_pool_id = aws_cognito_user_pool.pool.id
}

# COGNITO IDENTITY POOL
resource "aws_cognito_identity_pool" "idp" {
  identity_pool_name = "es_cognito_poc"

  allow_unauthenticated_identities = true # TEMPORARY WILL BE RESETTED AFTER ES_CLUSTER CREATION

  tags = local.tags
}

# COGNITO UNAUTHENTICATED ROLE
resource "aws_iam_role" "unauthenticated" {
  name = "es_cognito_poc_unauth_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.idp.id}"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "unauthenticated"
        }
      }
    }
  ]
}
EOF

  tags = local.tags
}

# COGNITO AUTHENTICATED ROLE
resource "aws_iam_role" "authenticated" {
  name = "es_cognito_poc_auth_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.idp.id}"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
EOF

  tags = local.tags
}

# BOND THE ABOVE ROLES TO CONGITO IdP
resource "aws_cognito_identity_pool_roles_attachment" "idp_roles_attachment" {
  identity_pool_id = aws_cognito_identity_pool.idp.id

  roles = {
    unauthenticated = aws_iam_role.unauthenticated.arn
    authenticated   = aws_iam_role.authenticated.arn
  }
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
resource "aws_security_group" "es_ec2_sg" {
  name = "es_cognito_poc_ec2_sg"

  vpc_id = module.vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["37.228.243.82/32"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      "37.228.243.82/32",
      "10.0.1.0/24",
      "10.0.2.0/24",
      "10.0.3.0/24"
    ]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      "37.228.243.82/32",
      "10.0.1.0/24",
      "10.0.2.0/24",
      "10.0.3.0/24"
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "es_sg" {
  name = "es_cognito_poc_es_sg"

  vpc_id = module.vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [
      aws_security_group.es_ec2_sg.id
    ]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [
      aws_security_group.es_ec2_sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

module "es_cluster" {
  source = "./modules/es_cluster"

  es_domain_name     = "es-cognito-poc-open-distro"
  subnet_ids         = module.subnet.created.*.id
  security_group_ids = [aws_security_group.es_sg.id]

  cognito_idp_id                    = aws_cognito_identity_pool.idp.id
  cognito_user_pool_id              = aws_cognito_user_pool.pool.id
  es_cognito_role_arn               = aws_iam_role.es_cognito_role.arn
  es_cognito_authenticated_role_arn = aws_iam_role.authenticated.arn

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
  subnet_ids = module.subnet.created.*.id
  security_group_ids = [
    aws_security_group.es_ec2_sg.id
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

  subnet_ids = module.subnet.created.*.id

  instances_template = {
    prefix        = "es_cognito_poc",
    ami-id        = data.aws_ami.default.image_id,
    instance-type = "t2.micro",
    iam-profile   = aws_iam_instance_profile.profile.name
    security-groups = [
      aws_security_group.es_ec2_sg.id
    ],
    user-data        = file("${path.module}/bootstrap.sh"),
    root-volume-size = 30
  }

  lb_target_group_arns = [
    module.alb.target_group_arn
  ]

  tags = local.tags
}
