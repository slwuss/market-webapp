variable "ami_id" {
  description = "AMI ID for the bastion host."
  type        = string
}

variable "instance_type" {
  description = "Instance type used for the bastion host."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the bastion host in."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the bastion security group."
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to access the bastion host via SSH."
  type        = list(string)
}

variable "key_name" {
  description = "SSH key name for the bastion host."
  type        = string
}

variable "private_key_path" {
  description = "Local path where the generated private key is written."
  type        = string
}

variable "security_group_name" {
  description = "Name for the bastion security group."
  type        = string
}

variable "instance_name" {
  description = "Name tag for the bastion instance."
  type        = string
}

variable "monitoring" {
  description = "Enable detailed monitoring for the bastion instance."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags for bastion resources."
  type        = map(string)
  default     = {}
}
