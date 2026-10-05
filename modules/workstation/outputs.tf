output "security_group_id" {
  description = "Security group of the workstation - databases allow it by reference."
  value       = aws_security_group.this.id
}

output "instance_id" {
  description = "EC2 instance id."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP. Reachable only from admin_cidrs, if any."
  value       = aws_instance.this.public_ip
}

output "admin_password_command" {
  description = "Decrypts the Administrator password with the key pair."
  value       = "aws ec2 get-password-data --instance-id ${aws_instance.this.id} --priv-launch-key <path-to>/${var.key_name}.pem --region ${var.aws_region}${local.profile_flag}"
}

output "rdp_over_ssm_command" {
  description = "Forwards RDP to localhost:13389 through Session Manager, with no open port."
  value       = "aws ssm start-session --target ${aws_instance.this.id} --document-name AWS-StartPortForwardingSession --parameters \"portNumber=3389,localPortNumber=13389\" --region ${var.aws_region}${local.profile_flag}"
}
