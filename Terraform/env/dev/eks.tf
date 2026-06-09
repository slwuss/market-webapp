resource "aws_security_group" "add_sg_eks" {
  name   = "additional-eks-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "HTTPS from bastion host"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [module.bastion.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "additional-eks-sg"
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name                             = var.cluster_name
  kubernetes_version                       = var.kubernetes_version
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  additional_security_group_ids            = [aws_security_group.add_sg_eks.id]
  instance_types                           = var.node_group_instance_types
  min_size                                 = var.node_group_min_size
  max_size                                 = var.node_group_max_size
  desired_size                             = var.node_group_desired_size
  tags                                     = var.tags
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  endpoint_public_access                   = var.endpoint_public_access
}
