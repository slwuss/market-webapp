module "vpc" {
  source = "../../modules/vpc"

  name = "${var.vpc_name}-${var.environment}"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = var.single_nat_gateway

  tags                = var.tags
  public_subnet_tags  = {}
  private_subnet_tags = {}
}
