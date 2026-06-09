module "bastion" {
  source = "../../modules/bastion"

  ami_id              = data.aws_ami.ubuntu.id
  instance_type       = var.bastion_instance_type
  subnet_id           = element(module.vpc.public_subnets, 0)
  vpc_id              = module.vpc.vpc_id
  allowed_cidrs       = var.bastion_allowed_cidrs
  key_name            = "${var.vpc_name}-${var.environment}-bastion-key"
  private_key_path    = "bastion-key.pem"
  security_group_name = "${var.vpc_name}-${var.environment}-bastion-sg"
  instance_name       = "${var.vpc_name}-${var.environment}-bastion"
  tags                = var.tags
}
