variable "name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "subnet_ids" {
  description = "VPC Subnets ids to place resources in"
  type        = list(string)
}

variable "instances_template" {
  description = "Define a template used to spin up instances"
  type        = any
  default = {
    prefix           = "",
    ami-id           = "",
    instance-type    = "",
    iam-profile      = "",
    security-groups  = [],
    user-data        = "",
    root-volume-size = 0
  }
}

variable "asg_max" {
  description = "Auto Scaling Group Max Instances"
  type        = number
  default     = 7
}

variable "asg_min" {
  description = "Auto Scaling Group Min Instances"
  type        = number
  default     = 3
}

variable "asg_desidered" {
  description = "Auto Scaling Group Desidered Capacity"
  type        = number
  default     = 6
}

variable "lb_target_group_arns" {
  description = "List of LBs target group arns. All the machine created will be automatically added to that target group"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
