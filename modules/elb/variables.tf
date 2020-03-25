variable "name" {
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

variable "certificate_arn" {
  type = string
}

variable "internal" {
  type    = bool
  default = false
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "health_check_protocol" {
  type    = string
  default = "HTTPS"
}

variable "tags" {
  type    = map(string)
  default = {}
}
