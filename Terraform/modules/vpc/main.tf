module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway      = var.enable_nat_gateway
  enable_vpn_gateway      = false
  single_nat_gateway      = var.single_nat_gateway
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = var.name
  })

  public_subnet_tags = merge(var.public_subnet_tags, {
    "kubernetes.io/role/elb" = "1"
  })
  private_subnet_tags = merge(var.private_subnet_tags, {
    "kubernetes.io/role/internal-elb" = "1"
  })
}
