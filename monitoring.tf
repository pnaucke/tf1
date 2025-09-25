# ----------------------
# Security Group voor monitoring
# ----------------------
resource "aws_security_group" "monitor_sg" {
  name   = "monitor-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH; kan beperken tot jouw IP
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Grafana; productie: beperk tot trusted IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "monitor-sg" }
}

# ----------------------
# Allow monitor to scrape node_exporter (9100) on web servers
# ----------------------
resource "aws_security_group_rule" "allow_monitor_to_node_exporter" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.monitor_sg.id
}

# ----------------------
# Monitoring instance
# ----------------------
resource "aws_instance" "monitor" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.web1_subnet.id
  vpc_security_group_ids = [aws_security_group.monitor_sg.id]
  key_name               = "Project1"

  user_data = <<-EOT
    #!/bin/bash
    set -e

    # Update en tools
    yum update -y
    yum install -y wget tar git fontconfig freetype* urw-fonts

    # Prometheus installatie
    useradd --no-create-home --shell /bin/false prometheus || true
    mkdir -p /opt/prometheus/data
    chown -R prometheus:prometheus /opt/prometheus

    PROM_VER="2.47.0"
    cd /opt
    wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz"
    tar xzf prometheus-${PROM_VER}.linux-amd64.tar.gz
    mv prometheus-${PROM_VER}.linux-amd64 prometheus
    chown -R prometheus:prometheus /opt/prometheus

    # Prometheus config
    cat > /opt/prometheus/prometheus.yml <<PROMYML
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ["${aws_instance.web1.private_ip}:9100","${aws_instance.web2.private_ip}:9100"]
PROMYML

    # Prometheus systemd service
    cat > /etc/systemd/system/prometheus.service <<PROMUNIT
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data
Restart=always

[Install]
WantedBy=multi-user.target
PROMUNIT

    systemctl daemon-reload
    systemctl enable --now prometheus

    # Grafana installatie (RPM direct)
    yum install -y https://dl.grafana.com/oss/release/grafana-10.0.0-1.x86_64.rpm

    # Grafana provisioning (datasource Prometheus)
    mkdir -p /etc/grafana/provisioning/datasources
    cat > /etc/grafana/provisioning/datasources/prometheus.yml <<GFYML
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
GFYML

    systemctl enable --now grafana-server

    # wacht even en reset admin wachtwoord (optioneel)
    sleep 5
    grafana-cli admin reset-admin-password AdminPass123! || true

    echo "Grafana beschikbaar op http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
  EOT

  tags = { Name = "monitor" }

  depends_on = [aws_instance.web1, aws_instance.web2]
}

# ----------------------
# Outputs
# ----------------------
output "grafana_public_ip" {
  value = aws_instance.monitor.public_ip
}

output "grafana_url" {
  value = "http://${aws_instance.monitor.public_ip}:3000"
}