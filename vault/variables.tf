variable "admin_passwd" {
  type      = string
  sensitive = true
}

variable "aws_consul_iam_role_arn" {
  type = string
}

variable "azure_consul_user_assigned_identity_principal_id" {
  type = string
}
