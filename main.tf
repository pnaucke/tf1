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
# Variabelen (voor eenvoud in 1 bestand)
# ----------------------
variable "web1_name" { default = "web1" }
variable "web2_name" { default = "web2" }
variable "db_name"   { default = "database" }

variable "web1_ip" { default = "172.31.0.10" }
variable "web2_ip" { default = "172.31.0.11" }
variable "db_ip"   { default = "172.31.16.10" }

# ----------------------
# Data default VPC
# ----------------------
data "aws_vpc" "default" {
  default = true
}

# ----------------------
# Subnets
# ----------------------
resource "aws_subnet" "subnet_a" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.0.0/20"
  availability_zone = "eu-central-1a"
  tags = { Name = "subnet-a" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.16.0/20"
  availability_zone = "eu-central-1b"
  tags = { Name = "subnet-b" }
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
    cidr_blocks = ["0.0.0.0/0"] # publiek toegankelijk
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
    security_groups = [aws_security_group.web_sg.id] # alleen web SG toegang
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
  ami           = "ami-07e9032b01a41341a" # Amazon Linux 2 x86_64
  instance_type = "t2.micro"
  private_ip    = var.web1_ip
  subnet_id     = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web1_name }
}

resource "aws_instance" "web2" {
  ami           = "ami-07e9032b01a41341a"
  instance_type = "t2.micro"
  private_ip    = var.web2_ip
  subnet_id     = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web2_name }
}

resource "aws_instance" "db" {
  ami           = "ami-07e9032b01a41341a"
  instance_type = "t2.micro"
  private_ip    = var.db_ip
  subnet_id     = aws_subnet.subnet_b.id
  security_groups = [aws_security_group.db_sg.name]
  tags = { Name = var.db_name }
}
