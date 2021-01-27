# Generic K/V
resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  description = "Key value secret engines"
}

# PKI
resource "vault_mount" "pki" {
  path                      = "pki"
	type = "pki"
  default_lease_ttl_seconds = 2764800  # 32  days
  max_lease_ttl_seconds     = 31536000 # 1 year
}

resource "vault_pki_secret_backend_role" "role" {
  backend = vault_mount.pki.path
  name    = "consul"

  allowed_domains  = ["consul", "internal"]
  allow_subdomains = true
}

resource "vault_pki_secret_backend_root_cert" "root_cert" {
  depends_on = [vault_mount.pki]

  backend = vault_mount.pki.path

  type                 = "internal"
  common_name          = "Consul CA"
  ttl                  = "315360000"
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 4096
  exclude_cn_from_sans = true
  ou                   = "My OU"
  organization         = "Masa consul mesh demo"
}

# AWS auth
