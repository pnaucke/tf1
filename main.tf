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
# Default VPC
# ----------------------
data "aws_vpc" "default" {
  default = true
}

# ----------------------
# Subnets
# ----------------------
resource "aws_subnet" "web1_subnet" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = { Name = "web1-subnet" }
}

resource "aws_subnet" "web2_subnet" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = { Name = "web2-subnet" }
}

# Twee DB-subnets in verschillende AZ’s (vereist voor RDS)
resource "aws_subnet" "db_subnet1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.3.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false
  tags = { Name = "db-subnet-1" }
}

resource "aws_subnet" "db_subnet2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.4.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = false
  tags = { Name = "db-subnet-2" }
}

# ----------------------
# AMI en random suffix
# ----------------------
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
# Security Groups
# ----------------------
resource "aws_security_group" "web_sg" {
  name   = "web-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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
# RDS Database
# ----------------------
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.db_subnet1.id, aws_subnet.db_subnet2.id]
}

resource "aws_db_instance" "db" {
  identifier              = "mydb-${random_id.suffix.hex}"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "myappdb"
  username                = "admin"
  password                = "SuperSecret123!"
  parameter_group_name    = "default.mysql8.0"
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible     = false
}

# ----------------------
# User Data (Nginx + PHP testpagina)
# ----------------------
locals {
  user_data = <<-EOT
    #!/bin/bash
    yum update -y
    amazon-linux-extras enable nginx1
    amazon-linux-extras enable php8.0
    yum install -y nginx php php-fpm php-mysqlnd mysql

    systemctl start nginx
    systemctl enable nginx
    systemctl start php-fpm
    systemctl enable php-fpm

    # PHP-FPM configureren voor TCP
    sed -i 's/^;listen = .*/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf
    systemctl restart php-fpm
    systemctl restart nginx

    # Configureer Nginx om PHP te gebruiken
    cat > /etc/nginx/conf.d/default.conf <<'EOF'
    server {
        listen       80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        index index.php index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
    EOF

    systemctl reload nginx

    # Maak test PHP pagina
    cat > /usr/share/nginx/html/index.php <<'EOF'
    <?php
    $server_ip = $_SERVER['SERVER_ADDR'];

    // Database config uit environment
    $db_host = getenv('DB_HOST');
    $db_port = getenv('DB_PORT');
    $db_user = getenv('DB_USER');
    $db_pass = getenv('DB_PASS');
    $db_name = getenv('DB_NAME');

    echo "<h1>Webserver IP: $server_ip</h1>";

    $conn = @mysqli_connect($db_host, $db_user, $db_pass, $db_name, $db_port);

    if ($conn) {
        echo "<p style='color:green'>✅ Database connectie OK</p>";
        $res = mysqli_query($conn, "SELECT NOW() as tijd");
        $row = mysqli_fetch_assoc($res);
        echo "<p>Database tijd: " . $row['tijd'] . "</p>";
        mysqli_close($conn);
    } else {
        echo "<p style='color:red'>❌ Database connectie mislukt: " . mysqli_connect_error() . "</p>";
    }
    ?>
    EOF
  EOT
}

# ----------------------
# Webservers
# ----------------------
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
# Load Balancer
# ----------------------
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.web1_subnet.id, aws_subnet.web2_subnet.id]
  security_groups    = [aws_security_group.web_sg.id]
}

resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
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

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "web1_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

# ----------------------
# Outputs
# ----------------------
output "load_balancer_dns" {
  value = aws_lb.web_lb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.address
}