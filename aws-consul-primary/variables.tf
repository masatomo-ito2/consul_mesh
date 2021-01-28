variable "vpc_id" {
  type = string
}

variable "region" {
  type = string
}

variable "ssh_key_name" {
  type = string
}

variable "public_subnets_id" {
  type = list(string)
}

variable "aws_consul_iam_instance_profile_name" {
  type = string
}

variable "env" {
  type = string
}

variable "vault_addr" {
  type = string
}

variable "vault_namespace" {
  type = string
}

variable "admin_passwd" {
  type = string
}

variable "role_id" {
  type = string
}

variable "secret_id" {
  type = string
}

