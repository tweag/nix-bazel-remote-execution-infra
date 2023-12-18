resource "aws_key_pair" "nix_server_key" {
  key_name   = "nix-server-key"
  public_key = var.public_ssh_key
  tags       = var.tags
}

module "server" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.5.0"

  name = "${var.prefix}-server"

  ami                    = var.ami
  instance_type          = var.nix_server_instance_type
  key_name               = aws_key_pair.nix_server_key.key_name
  monitoring             = true
  vpc_security_group_ids = [module.instance_security_group.security_group_id, module.nfs_security_group.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]

  associate_public_ip_address = true

  root_block_device = [{
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.nix_server_volume_size
  }]

  tags = merge(var.tags, {
    "component" = "server"
  })
}

module "instance_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.prefix}-access"
  description = "Security group for the Bazel Nix instances"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
  egress_rules        = ["all-all"]

  tags = var.tags
}

module "nfs_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "${var.prefix}-nfs-access"
  description = "Security group for the NFS server"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [var.vpc_cidr]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]

  tags = var.tags
}
