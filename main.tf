terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "eu-central-1"
}

# ----------------------
# Huidige default VPC gebruiken
# ----------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "random_id" "suffix" {
  byte_length = 2
}

# ----------------------
# Key Pair
# ----------------------
resource "aws_key_pair" "project1" {
  key_name   = "Project1"
  public_key = file("Project1.pub")
}

# ----------------------
# Security Groups
# ----------------------
resource "aws_security_group" "web_sg" {
  name   = "web-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------
# EC2 Instances
# ----------------------
resource "aws_instance" "web1" {
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = "t2.micro"
  subnet_id               = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids  = [aws_security_group.web_sg.id]
  key_name                = aws_key_pair.project1.key_name

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello World from Web1" > /var/www/html/index.html
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              EOF

  tags = { Name = "web1" }
}

resource "aws_instance" "web2" {
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = "t2.micro"
  subnet_id               = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids  = [aws_security_group.web_sg.id]
  key_name                = aws_key_pair.project1.key_name

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello World from Web2" > /var/www/html/index.html
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              EOF

  tags = { Name = "web2" }
}

resource "aws_instance" "db" {
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = "t2.micro"
  subnet_id               = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  key_name                = aws_key_pair.project1.key_name

  tags = { Name = "database" }
}

# ----------------------
# Load Balancer
# ----------------------
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "web1" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}