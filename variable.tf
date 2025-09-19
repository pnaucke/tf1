variable "aws_region" {
  description = "AWS regio waarin de resources komen"
  type        = string
  default     = "eu-west-1"
}

# Hub & Spoke CIDR blocks
variable "hub_cidr" {
  description = "CIDR block voor hub VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_cidr" {
  description = "CIDR block voor spoke VPC"
  type        = string
  default     = "10.1.0.0/16"
}

# Subnet CIDRs (kan je later aanpassen)
variable "hub_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "spoke_subnet_cidr" {
  default = "10.1.1.0/24"
}

# Namen van servers
variable "web1_name" { default = "web1" }
variable "web2_name" { default = "web2" }
variable "db_name"   { default = "database" }

# IP adressen van servers
variable "web1_ip" { default = "10.1.1.10" }
variable "web2_ip" { default = "10.1.1.11" }
variable "db_ip"   { default = "10.1.1.20" }