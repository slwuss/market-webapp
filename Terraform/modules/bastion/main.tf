resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion_keypair" {
  key_name   = var.key_name
  public_key = tls_private_key.bastion_key.public_key_openssh
}

resource "local_file" "bastion_private_key" {
  content         = tls_private_key.bastion_key.private_key_pem
  filename        = var.private_key_path
  file_permission = "0400"
}

resource "aws_security_group" "bastion" {
  name   = var.security_group_name
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_cidrs
    content {
      description      = "SSH access from allowed CIDR"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = [ingress.value]
      ipv6_cidr_blocks = []
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = var.security_group_name
  })
}

resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.bastion_keypair.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  associate_public_ip_address = true
  monitoring                  = var.monitoring

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}
