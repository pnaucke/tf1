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
  region = "eu-central-1" # pas aan als je een andere regio wilt
}

# ----------------------
# Bestaande default VPC
# ----------------------
data "aws_vpc" "default" {
  id = "vpc-02ef01d6d3413d850"
}

# ----------------------
# Subnets
# ----------------------
resource "aws_subnet" "subnet_a" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "eu-central-1a"
  tags = { Name = "subnet-a" }
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
    cidr_blocks = ["0.0.0.0/0"] # webservers bereikbaar van buiten
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
    security_groups = [aws_security_group.web_sg.id] # alleen webservers mogen verbinden
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
  ami             = "ami-07e9032b01a41341a" # AMI uit jouw regio
  instance_type   = "t2.micro"
  private_ip      = "10.1.1.10"
  subnet_id       = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = "web1" }
}

resource "aws_instance" "web2" {
  ami             = "ami-07e9032b01a41341a"
  instance_type   = "t2.micro"
  private_ip      = "10.1.1.11"
  subnet_id       = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = "web2" }
}

resource "aws_instance" "db" {
  ami             = "ami-07e9032b01a41341a"
  instance_type   = "t2.micro"
  private_ip      = "10.1.1.20"
  subnet_id       = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.db_sg.name]
  tags = { Name = "database" }
}