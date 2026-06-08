output "cluster_name" {
  description = "Name of the created EKS cluster."
  value       = module.eks.cluster_name
}
output "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = module.eks.cluster_endpoint
}
output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = module.bastion.bastion_public_ip
}
output "vpc_id" {
  value = module.vpc.vpc_id
}