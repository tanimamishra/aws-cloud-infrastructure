provider "aws" {
  region = "ap-south-1"
}

data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../vpc/terraform.tfstate"
  }
}

# Launch Template - defines what each EC2 instance looks like
resource "aws_launch_template" "app" {
  name_prefix   = "app-server-"
  image_id      = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [data.terraform_remote_state.vpc.outputs.ec2_sg_id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
  EOF
  )

  tags = {
    Name = "app-server"
  }
}

# Auto Scaling Group - manages multiple EC2 instances
resource "aws_autoscaling_group" "app" {
  name                = "app-asg"
  vpc_zone_identifier = [
    data.terraform_remote_state.vpc.outputs.private_subnet_1_id,
    data.terraform_remote_state.vpc.outputs.private_subnet_2_id
  ]
  desired_capacity    = 2
  min_size            = 1
  max_size            = 4

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy - scale up when CPU is high
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}