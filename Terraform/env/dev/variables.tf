variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_name" {
  description = "Name prefix for the VPC module."
  type        = string
  default     = "market-project"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the VPC subnets."
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT gateway for private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Whether to use a single NAT gateway for the private subnets."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "marketApp-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS."
  type        = string
  default     = "1.35"
}

variable "node_group_instance_types" {
  description = "EKS node group instance types."
  type        = list(string)
  default     = ["c7i-flex.large"]
}

variable "node_group_min_size" {
  description = "Minimum number of EKS nodes."
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of EKS nodes."
  type        = number
  default     = 10
}

variable "node_group_desired_size" {
  description = "Desired number of EKS nodes."
  type        = number
  default     = 2
}

variable "bastion_instance_type" {
  description = "Instance type used for the bastion host."
  type        = string
  default     = "t3.micro"
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to the bastion host."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Add the current identity as admin in the EKS cluster."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS API endpoint should be publicly accessible."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}
