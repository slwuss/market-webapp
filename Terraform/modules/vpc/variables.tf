variable "name" {
  description = "Name prefix for the VPC."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "azs" {
  description = "List of availability zones."
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks."
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways."
  type        = bool
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway when true."
  type        = bool
}

variable "tags" {
  description = "Common tags for all VPC resources."
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Tags for public subnets."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Tags for private subnets."
  type        = map(string)
  default     = {}
}
