output "bastion_public_ip" {
  description = "Public IP address of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "bastion_key_name" {
  description = "SSH key pair name for the bastion host."
  value       = aws_key_pair.bastion_keypair.key_name
}

output "bastion_private_key_path" {
  description = "Local path where the bastion private key was written."
  value       = local_file.bastion_private_key.filename
}

output "security_group_id" {
  description = "Security group ID used by the bastion host."
  value       = aws_security_group.bastion.id
}
