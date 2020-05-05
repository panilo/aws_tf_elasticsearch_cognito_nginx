output "es_sg_id" {
  value = aws_security_group.es_sg.id
}

output "es_ec2_sg_id" {
  value = aws_security_group.es_ec2_sg.id
}

output "subnet_ids" {
  value = module.subnet.created.*.id
}

output "vpc_id" {
  value = module.vpc.id
}
