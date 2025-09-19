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
  region = var.aws_region
}

# ----------------------
# Haal default VPC op
# ----------------------
data "aws_vpc" "default" {
  default = true
}

# ----------------------
# Subnet in default VPC
# ----------------------
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Voor dit voorbeeld pakken we het eerste subnet
locals {
  default_subnet_id = data.aws_subnets.default.ids[0]
}

# ----------------------
# Security Groups in default VPC
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
# Webservers
# ----------------------
resource "aws_instance" "web1" {
  ami                    = "ami-07e9032b01a41341a"
  instance_type          = "t2.micro"
  private_ip             = var.web1_ip
  subnet_id              = local.default_subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags                   = { Name = var.web1_name }
}

resource "aws_instance" "web2" {
  ami                    = "ami-07e9032b01a41341a"
  instance_type          = "t2.micro"
  private_ip             = var.web2_ip
  subnet_id              = local.default_subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags                   = { Name = var.web2_name }
}

# ----------------------
# Database
# ----------------------
resource "aws_instance" "db" {
  ami                    = "ami-07e9032b01a41341a"
  instance_type          = "t2.micro"
  private_ip             = var.db_ip
  subnet_id              = local.default_subnet_id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  tags                   = { Name = var.db_name }
}