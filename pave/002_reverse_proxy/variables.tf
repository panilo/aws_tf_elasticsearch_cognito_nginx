variable "es_domain_endpoint" {
  type = string
}

variable "cognito_domain_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "tags" {
  type = map(string)
}
