resource "vault_policy" "admin" {
  name = "admin"

  policy = <<EOT
path "*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

resource "vault_policy" "connect" {
  name = "connect"

  policy = <<EOT
path "connect-root/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "connect-intermediate*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/mounts"
{
  capabilities = ["create","update","read","sudo"]
}
path "sys/mounts/*"
{
  capabilities = ["create","update","read","sudo"]
}
path "auth/token/lookup" {
  capabilities = ["create","update"]
}
EOT
}

resource "vault_policy" "vault" {
  name = "vault"

  policy = <<EOT
path "kv/data/consul"
{
  capabilities = ["read"]
}
path "pki/cert/ca"
{
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "consul" {
  name = "consul"

  policy = <<EOT
path "kv/data/consul"
{
  capabilities = ["read"]
}
path "pki/issue/consul"
{
  capabilities = ["read","update"]
}
path "pki/cert/ca"
{
  capabilities = ["read"]
}
EOT
}
