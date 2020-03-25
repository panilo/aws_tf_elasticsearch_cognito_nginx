variable "es_domain_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_idp_id" {
  type = string
}

variable "es_cognito_role_arn" {
  type = string
}

variable "es_cognito_authenticated_role_arn" {
  type = string
}

variable "es_version" {
  type    = string
  default = "7.4"
}

variable "cluster_master_node_count" {
  type    = number
  default = 3
}

variable "cluster_master_node_instance_type" {
  type    = string
  default = "c5.large.elasticsearch"
}

variable "cluster_node_count" {
  type    = number
  default = 3
}

variable "cluster_node_instance_type" {
  type    = string
  default = "r5.large.elasticsearch"
}

variable "ebs_type" {
  type    = string
  default = "gp2"
}

variable "ebs_size" {
  type    = number
  default = 10
}

variable "auto_snap_time" {
  type    = number
  default = 23
}

variable "tags" {
  type    = map(string)
  default = {}
}
