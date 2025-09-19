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
# Hub VPC en subnet
# ----------------------
resource "aws_vpc" "hub" {
  cidr_block = var.hub_cidr
  tags = { Name = "hub-vpc" }
}

resource "aws_subnet" "hub_subnet" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = var.hub_subnet_cidr
  availability_zone = "${var.aws_region}a"
  tags = { Name = "hub-subnet" }
}

# ----------------------
# Spoke VPC en subnet
# ----------------------
resource "aws_vpc" "spoke" {
  cidr_block = var.spoke_cidr
  tags = { Name = "spoke-vpc" }
}

resource "aws_subnet" "spoke_subnet" {
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = var.spoke_subnet_cidr
  availability_zone = "${var.aws_region}a"
  tags = { Name = "spoke-subnet" }
}

# ----------------------
# Security Groups
# ----------------------
resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.spoke.id

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
  vpc_id = aws_vpc.spoke.id

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [aws_security_group.web_sg.id]
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
  ami           = "ami-07e9032b01a41341a"
  instance_type = "t2.micro"
  private_ip    = var.web1_ip
  subnet_id     = aws_subnet.spoke_subnet.id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web1_name }
}

resource "aws_instance" "web2" {
  ami           = "ami-07e9032b01a41341a"
  instance_type = "t2.micro"
  private_ip    = var.web2_ip
  subnet_id     = aws_subnet.spoke_subnet.id
  security_groups = [aws_security_group.web_sg.name]
  tags = { Name = var.web2_name }
}

# ----------------------
# Database
# ----------------------
resource "aws_instance" "db" {
  ami           = "ami-07e9032b01a41341a"
  instance_type = "t2.micro"
  private_ip    = var.db_ip
  subnet_id     = aws_subnet.spoke_subnet.id
  security_groups = [aws_security_group.db_sg.name]
  tags = { Name = var.db_name }
}