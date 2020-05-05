# CREATE VPC
module "vpc" {
  source = "../../modules/vpc"

  name       = "es_cognito_poc_vpc"
  cidr_block = "10.0.0.0/16"
  tags       = var.tags
}

# CREATE ONE SUBNET FOR AZ
module "subnet" {
  source = "../../modules/subnet"

  name       = "es_cognito_poc_sn"
  vpc_id     = module.vpc.id
  cidr_block = "10.0.X.0/24"
  tags       = var.tags
}

# CREATE SECURITY GROUPS
resource "aws_security_group" "es_ec2_sg" {
  name = "es_cognito_poc_ec2_sg"

  vpc_id = module.vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      "37.228.249.103/32",
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
      "37.228.249.103/32",
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

  tags = var.tags
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

  tags = var.tags
}

