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

# Variabelen

variable "aws_region" {
  description = "AWS regio waarin de resources komen"
  type        = string
  default     = "eu-central-1"
}

# Servernamen
variable "web1_name" { default = "web1" }
variable "web2_name" { default = "web2" }
variable "db_name"   { default = "database" }

# IP adressen van servers
variable "web1_ip" { default = "10.1.1.10" }
variable "web2_ip" { default = "10.1.1.11" }
variable "db_ip"   { default = "10.1.1.20" }

# Bestaande VPC en subnets

data "aws_vpc" "existing" {
  id = "vpc-02ef01d6d3413d850"
}

data "aws_subnet" "subnet_a" {
  id = "subnet-0ca438cc517db7edf"
}

data "aws_subnet" "subnet_b" {
  id = "subnet-0adf7de4d0fe3974b"
}

# Security Groups

resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = data.aws_vpc.existing.id

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
  vpc_id = data.aws_vpc.existing.id

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

# Amazon Linux AMI ophalen

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Webservers

resource "aws_instance" "web1" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  private_ip    = var.web1_ip
  subnet_id     = data.aws_subnet.subnet_a.id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web1_name }
}

resource "aws_instance" "web2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  private_ip    = var.web2_ip
  subnet_id     = data.aws_subnet.subnet_b.id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web2_name }
}

# Database server

resource "aws_instance" "db" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  private_ip    = var.db_ip
  subnet_id     = data.aws_subnet.subnet_b.id
  security_groups = [aws_security_group.db_sg.name]
  tags = { Name = var.db_name }
}