output "ec2_public_ip" {
  description = "Elastic IP attached to the ecommerce-server instance."
  value       = aws_eip.ecommerce.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.ecommerce.id
}

output "ec2_availability_zone" {
  description = "AZ in which the EC2 instance is running."
  value       = aws_instance.ecommerce.availability_zone
}

output "domain" {
  description = "Application domain pointed at the EC2 instance."
  value       = var.domain
}
