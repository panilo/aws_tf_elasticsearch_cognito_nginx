
# GET REGION AND IDENTITY

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_elasticsearch_domain" "es" {

  domain_name           = var.es_domain_name
  elasticsearch_version = var.es_version

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled = true
  }

  cluster_config {
    dedicated_master_enabled = true
    dedicated_master_count   = var.cluster_master_node_count
    dedicated_master_type    = var.cluster_master_node_instance_type

    instance_count = var.cluster_node_count
    instance_type  = var.cluster_node_instance_type

    zone_awareness_enabled = true
    zone_awareness_config {
      availability_zone_count = length(var.subnet_ids)
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.ebs_type
    volume_size = var.ebs_size
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  access_policies = <<CONFIG
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": [
            "${var.es_cognito_authenticated_role_arn}"
          ]
        },
        "Action": [
          "es:*"
        ],
        "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.es_domain_name}/*"
      }
    ]
  }
  CONFIG

  cognito_options {
    enabled          = true
    user_pool_id     = var.cognito_user_pool_id
    identity_pool_id = var.cognito_idp_id
    role_arn         = var.es_cognito_role_arn
  }

  snapshot_options {
    automated_snapshot_start_hour = var.auto_snap_time
  }

  tags = var.tags
}
