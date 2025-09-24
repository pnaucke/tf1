# ----------------------
# Security Group DB aanpassen (alleen webservers mogen inloggen)
# ----------------------
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
# RDS Database (vervangt de EC2 database)
# ----------------------
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.db_subnet.id]
}

resource "aws_db_instance" "db" {
  identifier              = "mydb-${random_id.suffix.hex}"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "myappdb"
  username                = "admin"
  password                = "SuperSecret123!"   # (=> later vervangen met Secret Manager)
  parameter_group_name    = "default.mysql8.0"
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible     = false
}

# ----------------------
# User Data voor webservers (NGINX + DB env vars)
# ----------------------
locals {
  user_data = <<-EOT
    #!/bin/bash
    yum update -y
    amazon-linux-extras enable nginx1
    yum install -y nginx mysql
    systemctl start nginx
    systemctl enable nginx

    echo "DB_HOST=${aws_db_instance.db.address}" >> /etc/environment
    echo "DB_PORT=${aws_db_instance.db.port}" >> /etc/environment
    echo "DB_USER=admin" >> /etc/environment
    echo "DB_PASS=SuperSecret123!" >> /etc/environment
    echo "DB_NAME=myappdb" >> /etc/environment
  EOT
}

resource "aws_instance" "web1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web1_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.user_data
  tags = { Name = "web1" }
}

resource "aws_instance" "web2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web2_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.user_data
  tags = { Name = "web2" }
}

# ----------------------
# Outputs (handig!)
# ----------------------
output "load_balancer_dns" {
  value = aws_lb.web_lb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.address
}