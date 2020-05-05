# COGNITO USER POOL
resource "aws_cognito_user_pool" "pool" {
  name = "${var.name}_user_pool"

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

  tags = var.tags
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.domain_name
  user_pool_id = aws_cognito_user_pool.pool.id
}

# COGNITO IDENTITY POOL
resource "aws_cognito_identity_pool" "idp" {
  identity_pool_name = "${var.name}_idp_pool"

  allow_unauthenticated_identities = true # TEMPORARY WILL BE RESETTED AFTER ES_CLUSTER CREATION

  tags = var.tags
}

# COGNITO UNAUTHENTICATED ROLE
resource "aws_iam_role" "unauthenticated" {
  name = "${var.name}_unauth_role"

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

  tags = var.tags
}

# COGNITO AUTHENTICATED ROLE
resource "aws_iam_role" "authenticated" {
  name = "${var.name}_auth_role"

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

  tags = var.tags
}

# BOND THE ABOVE ROLES TO CONGITO IdP
resource "aws_cognito_identity_pool_roles_attachment" "idp_roles_attachment" {
  identity_pool_id = aws_cognito_identity_pool.idp.id

  roles = {
    unauthenticated = aws_iam_role.unauthenticated.arn
    authenticated   = aws_iam_role.authenticated.arn
  }
}