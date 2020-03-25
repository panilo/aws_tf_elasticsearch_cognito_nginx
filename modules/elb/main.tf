resource "aws_lb" "default" {
  name               = var.name
  load_balancer_type = "application"

  internal        = var.internal
  security_groups = var.security_group_ids
  subnets         = var.subnet_ids

  tags = var.tags
}

resource "aws_lb_target_group" "default" {
  name = var.name

  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    path     = var.health_check_path
    protocol = var.health_check_protocol

    healthy_threshold   = 6
    unhealthy_threshold = 5

    timeout  = 3
    interval = 30
  }

  tags = var.tags
}

resource "aws_lb_listener" "default" {
  load_balancer_arn = aws_lb.default.arn

  port     = 443
  protocol = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}
