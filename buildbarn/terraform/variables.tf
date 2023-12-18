variable "aws_account_id" {
  type = string
}

variable "k8s_disk_size" {
  type    = number
  default = 80
}

variable "k8s_instance_types" {
  type    = list(string)
  default = ["m6i.xlarge"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.8.0.0/16"
}

variable "vpc_public_subnets" {
  type    = list(string)
  default = ["10.8.1.0/24", "10.8.2.0/24"]
}

variable "vpc_private_subnets" {
  type    = list(string)
  default = ["10.8.11.0/24", "10.8.12.0/24"]
}

variable "public_ssh_key" {
  type = string
}

variable "ami" {
  type = string
}

variable "nix_server_instance_type" {
  type    = string
  default = "m6i.large"
}

variable "nix_server_volume_size" {
  type    = number
  default = 60
}

variable "domain_name" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_azs" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}
