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

# Gebruik bestaande default VPC
data "aws_vpc" "default" {
  default = true
}

# Gebruik bestaande subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Groups (unieke namen)
resource "aws_security_group" "web_sg" {
  name   = "web-sg-1"
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
  name   = "db-sg-1"
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

# Webservers
resource "aws_instance" "web1" {
  ami             = "ami-07e9032b01a41341a"
  instance_type   = "t2.micro"
  subnet_id       = data.aws_subnets.default.ids[0]
  security_groups = [aws_security_group.web_sg.name]
  private_ip      = "10.0.1.10"
  tags = { Name = "web1" }
}

resource "aws_instance" "web2" {
  ami             = "ami-07e9032b01a41341a"
  instance_type   = "t2.micro"
  subnet_id       = data.aws_subnets.default.ids[1]
  security_groups = [aws_security_group.web_sg.name]
  private_ip      = "10.0.1.11"
  tags = { Name = "web2" }
}

# Database
resource "aws_instance" "db" {
  ami             = "ami-07e9032b01a41341a"
  instance_type   = "t2.micro"
  subnet_id       = data.aws_subnets.default.ids[2]
  security_groups = [aws_security_group.db_sg.name]
  private_ip      = "10.0.1.20"
  tags = { Name = "database" }
}