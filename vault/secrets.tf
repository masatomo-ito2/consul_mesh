# Master tokens
resource "random_uuid" "master_token" {}
resource "random_uuid" "replication_token" {}
resource "random_string" "gossip_key" {
  length = 32
}

# Put secrets into vault
resource "vault_generic_secret" "consul" {
  depends_on = [vault_mount.kv]
  path       = "kv/consul"

  data_json = <<EOT
{
    "master_token": "${random_uuid.master_token.result}",
    "replication_token": "${random_uuid.replication_token.result}",
    "gossip_key": "${base64encode(random_string.gossip_key.result)}"
}
EOT
}
