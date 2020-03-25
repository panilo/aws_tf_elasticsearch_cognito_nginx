output "created" {
  value = [for s in aws_subnet.multi_az : s]
}
