output "cluster_autoscaler_role" {
  value = module.cluster_autoscaler_irsa.iam_role_arn
}

output "ebs_csi_role" {
  value = module.ebs_csi_irsa.iam_role_arn
}

output "vpc_cni_role" {
  value = module.vpc_cni_irsa.iam_role_arn
}

output "external_dns_irsa" {
  value = module.external_dns_irsa.iam_role_arn
}

output "nix_server_public_ip" {
  value = module.server.public_ip
}

output "nix_server_private_ip" {
  value = module.server.private_ip
}

output "vpc_cidr" {
  value = var.vpc_cidr
}
