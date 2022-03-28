###########
# Instances
###########

resource "aws_instance" "mongo" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
#  subnet_id              = lookup(var.subnet_ids, var.region)
  vpc_security_group_ids = ["${aws_security_group.mongo.id}"]

  provisioner "file" {
    source      = "mongod.conf"
    destination = "/tmp/mongod.conf"
  }

  count = var.total_instances

  user_data = file("script.sh")

  tags = {
    Name = "${var.instance_prefix}${count.index + 1}"
  }

  associate_public_ip_address = true
  key_name                    = var.key_name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = var.instance_user
    private_key = file(var.private_key)
    agent       = false
  }
}

################################################
# Create AMI from newly created EC2 instance
################################################
resource "aws_ami_from_instance" "mongoami" {
  name               = "mongoami"
  source_instance_id = aws_instance.mongo[0].id
  tags = {
    ENV = "${var.environment_tag}"
  }
}

################################################
# Create Launch Tempate for ASG
################################################

resource "aws_launch_template" "mongoit" {
  name_prefix   = "mongoit"
  image_id      = aws_ami_from_instance.mongoami.id
  instance_type = var.instance_type
  key_name      = var.key_name
  tags = {
    Name = "mongoUI"
  }
}

#############################s###################
# Create placement group
################################################

resource "aws_placement_group" "mongoplacement" {
  name     = "mongoplacement"
  strategy = "spread"
}

################################################
# Create ASG
################################################

resource "aws_autoscaling_group" "mongoasg" {
  name                      = "mongo-ASG"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  placement_group           = aws_placement_group.mongoplacement.id
  availability_zones        = ["${aws_instance.mongo[0].availability_zone}"]
  target_group_arns         = ["${aws_lb_target_group.mongotargetgroup.arn}"]

  launch_template {
    id      = aws_launch_template.mongoit.id
    version = "$Default"
  }
}

################################################
# Create Loadbalancer target group
################################################

resource "aws_lb_target_group" "mongotargetgroup" {
  name        = "mongotargetgroup"
  port        = "27017"
  protocol    = "HTTP"
  vpc_id      = aws_default_vpc.default.id
  target_type = "instance"
  tags = {
    name = "mongoUItarget"
    ENV  = "${var.environment_tag}"
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = "27017"
  }
}

################################################
# Get default VPC
################################################

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}


################################################
# Get subnet zone1
################################################

resource "aws_default_subnet" "defaultsubnet1" {
  availability_zone = "us-west-2a"
  tags = {
    Name = "Default subnet1"
  }
}

################################################
# Get subnet zone2
################################################

resource "aws_default_subnet" "defaultsubnet2" {
  availability_zone = "us-west-2b"
  tags = {
    Name = "Default subnet2"
  }
}


################################################
# Create ELB - Application loadbalancer
################################################

resource "aws_lb" "mongoelb" {
  name               = "mongoelb"
  subnets            = ["${aws_default_subnet.defaultsubnet1.id}", "${aws_default_subnet.defaultsubnet2.id}"]
  internal           = false
  load_balancer_type = "application"
  # security_groups    = ["${aws_security_group.CF2TF-SG-Web.id}"]

  tags = {
    Name = "mongodp"
    ENV  = "${var.environment_tag}"
  }
}

################################################
# Create Application LB listener
################################################

resource "aws_lb_listener" "mongolistener" {
  load_balancer_arn = aws_lb.mongoelb.arn
  port              = "27017"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mongotargetgroup.arn
    type             = "forward"
  }
}

/*
##############################################################
# Terminate instance after creating AMI
##############################################################

resource "null_resource" "postexecution" {
  depends_on    = ["aws_ami_from_instance.mongoami"]
  connection {

    host        = "${aws_instance.mongo.public_ip}"
    user        = "${var.aws_default_user}"
    private_key = "${file(var.private_key)}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo init 0"
    ]
  }
}

##############################################################
# SNS notification if EC2 cpu usage more than 80%
##############################################################

resource "aws_sns_topic" "mongotopic" {
  name = "alarms-topic"
  provisioner "local-exec" {
    command = "export AWS_ACCESS_KEY_ID=${var.access_key} ; export AWS_SECRET_ACCESS_KEY=${var.secret_key}; aws sns subscribe --topic-arn ${aws_sns_topic.gogotopic.arn} --protocol email --notification-endpoint ${var.emails} --region ${var.region}"
  }
}
*/

##############################################################
# Cloudwatch Alarm if EC2 instance CPU usage reached 80 %    #
##############################################################

resource "aws_cloudwatch_metric_alarm" "mongohealth" {
  alarm_name = "ASG_Instance_CPU"
  #  depends_on            = [
  #      #aws_sns_topic.mongotopic, 
  #      aws_autoscaling_group.mongoasg,
  #      ]
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  #  alarm_actions       = ["${aws_sns_topic.mongotopic.arn}"]
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.mongoasg.name}"
  }
}

################
# Security Group
################

resource "aws_security_group" "mongo" {
  name   = var.sg_name
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.sg_name}"
  }
}

###############
# Elastic IP
###############

resource "aws_eip" "mongo" {
  count    = var.total_instances
  instance = element(aws_instance.mongo.*.id, count.index)
  vpc      = true
}
