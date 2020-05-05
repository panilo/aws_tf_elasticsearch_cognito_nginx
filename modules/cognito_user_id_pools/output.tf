output "idp_id" {
  value = aws_cognito_identity_pool.idp.id
}

output "user_pool_id" {
  value = aws_cognito_user_pool.pool.id
}

output "unauthenticated_role_arn" {
  value = aws_iam_role.unauthenticated.arn
}

output "authenticated_role_arn" {
  value = aws_iam_role.authenticated.arn
}