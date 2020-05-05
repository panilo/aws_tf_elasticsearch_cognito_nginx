# Create a Cloudformation template
# This will be used to call the lambda whose actually create the cluster
# FGA is not supported in TF / CF yet
# That's why we're using this workaround
data "template_file" "lambda_to_create_custom_resources" {
  template = file("${path.module}/cloudformation_resources/cf_custom_resource_tpl.json")
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Create the lambda whose carry on the creation
module "cr_lambda" {
  source = "../lambda"

  code_path = "${path.module}/cloudformation_resources/lambda_create_es_cluster"
  fn_name   = "lambda_cr_create_es_cluster"
  handler   = "lambda_create_es_cluster.handler"

  iam_policy_name       = "cr_cluster_policy"
  iam_policy_definition = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowAllESActions",
            "Effect": "Allow",
            "Action": "es:*",
            "Resource": "*"
        },
        {
          "Sid": "AllowCFPolling",
          "Effect": "Allow",
          "Action": [
            "lambda:AddPermission",
            "lambda:RemovePermission",
            "events:PutRule",
            "events:DeleteRule",
            "events:PutTargets",
            "events:RemoveTargets"
          ],
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
              "iam:PassRole"
          ],
          "Resource": "*"
        }
    ]
}
  EOF

  tags = var.tags
}

resource "aws_cloudformation_stack" "my_custom_resource" {
  name = "ESClusterFGADomainStack"

  template_body = data.template_file.lambda_to_create_custom_resources.rendered

  timeouts {
    create = "120m"
  }
  timeout_in_minutes = 120

  parameters = {
    LambdaArn               = module.cr_lambda.arn
    DomainName              = var.es_domain_name
    ESVersion               = var.es_version
    AutoSnapStartHour       = var.auto_snap_time
    DataNodeInstanceType    = var.cluster_node_instance_type
    DataNodeInstanceCount   = var.cluster_node_count
    MasterNodeInstanceType  = var.cluster_master_node_instance_type
    MasterNodeInstanceCount = var.cluster_master_node_count
    VolumeType              = var.ebs_type
    VolumeSize              = var.ebs_size
    SubnetIds               = join(",", var.subnet_ids)
    SecurityGroupIds        = join(",", var.security_group_ids)
    EbsEncryptionKmsKeyId   = var.ebs_encryption_kms_key_id
    AccessPolicies          = <<CONFIG
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
    UserPoolId              = var.cognito_user_pool_id
    IdpId                   = var.cognito_idp_id
    ESCognitoRoleArn        = var.es_cognito_role_arn
    MasterUserRoleArn       = var.es_cognito_authenticated_role_arn
  }

  tags = var.tags
}
