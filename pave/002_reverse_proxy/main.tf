# CREATE A SELF SIGNED CERTIFICATE TO BE USED IN THE ALB
module "ssc" {
  source = "../../modules/self_sign_acm_certificate"

  domain_name = "es-cognito-poc.com"

  tags = var.tags
}

# CREATE AN ALB
module "alb" {
  source = "../../modules/elb"

  name = "es-cognito-poc"

  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  certificate_arn = module.ssc.arn

  tags = var.tags
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

# GET ES DOMAIN
data "aws_elasticsearch_domain" "es_domain" {
  domain_name = var.es_domain_name
}

data "template_file" "bootstrap" {
  template = file("${path.module}/nginx.conf")

  vars = {
    es-cluster-endpoint = data.aws_elasticsearch_domain.es_domain.endpoint
    cognito_host        = "${var.cognito_domain_name}.auth.${var.region}.amazoncognito.com"
  }
}

resource "aws_s3_bucket" "config_bucket" {
  bucket = "es-cognito-poc-bucket"
  acl    = "private"

  tags = var.tags
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

  tags = var.tags
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
  source = "../../modules/asg"

  name = "es_cognito_poc"

  asg_min       = 1
  asg_max       = 3
  asg_desidered = 2

  subnet_ids = var.subnet_ids

  instances_template = {
    prefix           = "es_cognito_poc",
    ami-id           = data.aws_ami.default.image_id,
    instance-type    = "t2.micro",
    iam-profile      = aws_iam_instance_profile.profile.name
    security-groups  = var.security_group_ids,
    user-data        = file("${path.module}/bootstrap.sh"),
    root-volume-size = 30
  }

  lb_target_group_arns = [
    module.alb.target_group_arn
  ]

  tags = var.tags
}
