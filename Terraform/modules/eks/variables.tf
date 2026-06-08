variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy EKS into."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster."
  type        = list(string)
}

variable "additional_security_group_ids" {
  description = "List of security groups for the EKS cluster."
  type        = list(string)
  default     = []
}

variable "instance_types" {
  description = "Instance types for the EKS worker nodes."
  type        = list(string)
}

variable "min_size" {
  description = "Minimum node group size."
  type        = number
}

variable "max_size" {
  description = "Maximum node group size."
  type        = number
}

variable "desired_size" {
  description = "Desired node group size."
  type        = number
}

variable "tags" {
  description = "Tags to apply to the EKS cluster."
  type        = map(string)
  default     = {}
}

variable "addons" {
  description = "EKS addon configuration."
  type        = map(any)
  default = {
    coredns                = {}
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
  }
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable cluster creator admin permissions."
  type        = bool
}

variable "endpoint_public_access" {
  description = "Whether EKS endpoint is public."
  type        = bool
}
