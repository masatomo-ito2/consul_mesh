variable "admin_passwd" {
  type      = string
  sensitive = true
}

variable "aws_consul_iam_role_arn" {
  type = string
}
