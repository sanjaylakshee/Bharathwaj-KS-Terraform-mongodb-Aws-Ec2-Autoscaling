#

resource "aws_lb" "mongodb_lb" {
  name               = var.load_balancer_name
  internal           = true
  load_balancer_type = "network"
  subnets            = [var.subnet_id]
}

resource "aws_lb_target_group" "mongodb_lb_target_group" {
  port        = 27017
  protocol    = "TCP"
  vpc_id      = data.aws_subnet.subnet.vpc_id
  target_type = "instance"
}

resource "aws_lb_listener" "mongodb_lb_listener" {
  load_balancer_arn = aws_lb.mongodb_lb.arn
  port              = 27017
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.mongodb_lb_target_group.arn
    type             = "forward"
  }
}

resource "aws_autoscaling_group" "mongodb_asg" {
  name                = var.autoscalling_group_name
  vpc_zone_identifier = [var.subnet_id]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  health_check_type   = "EC2"

  target_group_arns = [aws_lb_target_group.mongodb_lb_target_group.arn]

  launch_template {
    id      = aws_launch_template.mongodb_launch_template.id
    version = aws_launch_template.mongodb_launch_template.latest_version
  }

  initial_lifecycle_hook {
    name                 = "attach-storage-volume-and-launch"
    default_result       = "ABANDON"
    heartbeat_timeout    = 300
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 0
    }
  }
}

/*
variable
/*

variable "autoscalling_group_name" {
  description = "Autoscalling group name"
  type        = string
}

variable "load_balancer_name" {
  description = "Load balancer name"
  type        = string
}

/*