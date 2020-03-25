output "name" {
  value = aws_lb.default.name
}

output "target_group_arn" {
  value = aws_lb_target_group.default.arn
}

output "endpoint" {
  value = aws_lb.default.dns_name
}
