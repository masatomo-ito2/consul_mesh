resource "vault_auth_backend" "userpass" {
  type = "userpass"

  tune {
    default_lease_ttl = "24h"
    max_lease_ttl     = "768h"
  }
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  tune {
    default_lease_ttl = "24h"
    max_lease_ttl     = "768h"
  }
}

resource "vault_auth_backend" "aws" {
  type = "aws"
  tune {
    default_lease_ttl = "24h"
    max_lease_ttl     = "768h"
  }
}

resource "vault_auth_backend" "azure" {
  type = "azure"
  tune {
    default_lease_ttl = "24h"
    max_lease_ttl     = "768h"
  }
}
