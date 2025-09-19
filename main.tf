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
  region = "eu-central-1"
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
# Default VPC gebruiken
# ----------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# ----------------------
# Laatste Amazon Linux 2 AMI
# ----------------------
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
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
# EC2 Instances
# ----------------------
resource "aws_instance" "web1" {
  ami             = data.aws_ami.amazon_linux_2.id
  instance_type   = "t2.micro"
  subnet_id       = data.aws_subnet_ids.default.ids[0]
  private_ip      = var.web1_ip
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web1_name }
}

resource "aws_instance" "web2" {
  ami             = data.aws_ami.amazon_linux_2.id
  instance_type   = "t2.micro"
  subnet_id       = data.aws_subnet_ids.default.ids[0]
  private_ip      = var.web2_ip
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web2_name }
}

resource "aws_instance" "db" {
  ami             = data.aws_ami.amazon_linux_2.id
  instance_type   = "t2.micro"
  subnet_id       = data.aws_subnet_ids.default.ids[0]
  private_ip      = var.db_ip
  security_groups = [aws_security_group.db_sg.name]
  tags = { Name = var.db_name }
}