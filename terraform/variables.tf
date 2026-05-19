variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-south-1"
}

variable "availability_zone" {
  description = "AZ for the public subnet and EC2 instance."
  type        = string
  default     = "ap-south-1a"
}

variable "my_ip" {
  description = "Admin IP (CIDR notation accepted; bare IP is auto-suffixed with /32) allowed to SSH on port 22."
  type        = string
}

variable "ec2_public_key" {
  description = "OpenSSH public key (ssh-rsa/ssh-ed25519 ...) injected into the EC2 key pair."
  type        = string
}

variable "domain" {
  description = "Apex application hostname served by the EC2 instance."
  type        = string
  default     = "ecommerce.nitinkdevs.com"
}

variable "root_domain" {
  description = "Route 53 hosted zone name (without trailing dot)."
  type        = string
  default     = "nitinkdevs.com"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}
