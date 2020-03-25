
resource "aws_launch_configuration" "default" {
  name_prefix   = var.instances_template["prefix"]
  image_id      = var.instances_template["ami-id"]
  instance_type = var.instances_template["instance-type"]

  iam_instance_profile = var.instances_template["iam-profile"]
  security_groups      = var.instances_template["security-groups"]

  user_data = var.instances_template["user-data"]

  root_block_device {
    encrypted   = true
    volume_size = var.instances_template["root-volume-size"]
  }

  lifecycle {
    create_before_destroy = true
  }

  key_name = "es_cognito_poc"
}

data "null_data_source" "tags_as_list_of_maps" {
  count = length(keys(var.tags))

  inputs = map(
    "key", element(keys(var.tags), count.index),
    "value", element(values(var.tags), count.index),
    "propagate_at_launch", true
  )
}

resource "aws_autoscaling_group" "default" {
  name = var.name

  max_size         = var.asg_max
  min_size         = var.asg_min
  desired_capacity = var.asg_desidered

  launch_configuration = aws_launch_configuration.default.name

  target_group_arns = var.lb_target_group_arns

  vpc_zone_identifier = var.subnet_ids

  tags = data.null_data_source.tags_as_list_of_maps.*.outputs
}
