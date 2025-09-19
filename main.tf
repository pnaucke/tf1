terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "eu-west-1"
}

# ----------------------
# Variabelen
# ----------------------
variable "web1_name" { default = "web1" }
variable "web2_name" { default = "web2" }
variable "db_name"   { default = "database" }

variable "web1_ip" { default = "10.0.1.10" }
variable "web2_ip" { default = "10.0.1.11" }
variable "db_ip"   { default = "10.0.1.20" }

# ----------------------
# Gebruik default VPC
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

# Kies de eerste subnet voor simplicity
locals {
  subnet_id = data.aws_subnets.default.ids[0]
}

# ----------------------
# Security Groups
# ----------------------
resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = data.aws_vpc.default.id

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
  name   = "db-sg"
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
# AMI ophalen (Amazon Linux 2)
# ----------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ----------------------
# EC2 Instances
# ----------------------
resource "aws_instance" "web1" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  private_ip    = var.web1_ip
  subnet_id     = local.subnet_id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web1_name }
}

resource "aws_instance" "web2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  private_ip    = var.web2_ip
  subnet_id     = local.subnet_id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web2_name }
}

resource "aws_instance" "db" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  private_ip    = var.db_ip
  subnet_id     = local.subnet_id
  security_groups = [aws_security_group.db_sg.name]
  tags = { Name = var.db_name }
}