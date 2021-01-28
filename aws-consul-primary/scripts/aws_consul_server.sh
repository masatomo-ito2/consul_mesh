#!/bin/bash

set -x
exec > >(tee /tmp/tf-user-data.log|logger -t vault_bootstrap ) 2>&1

logger() {
	DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT $0: $1"
}

echo set -o vi >> /home/ubuntu/.bashrc

logger "Running"

# install hashistack
apt update -y
apt install software-properties-common -y
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

#packages
apt update -y
apt install consul-enterprise vault-enterprise nomad-enterprise libcap-dev jq tree redis-server -y

#metadata
local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
logger "My local IP is $${local_ipv4}"


#vault
export VAULT_ADDR="${tpl_vault_addr}"
# vault login -method=aws role=consul
vault login -method=userpass -namespace=${tpl_namespace} username=admin password=${tpl_admin_passwd}
CONNECT_TOKEN=$(vault token create -namespace=${tpl_namespace} -field token -policy connect -orphan)

mkdir -p /etc/vault-agent.d/
mkdir -p /opt/consul/tls/

# Approle auth
echo ${tpl_role_id}   > /etc/vault-agent.d/role_id
echo ${tpl_secret_id} > /etc/vault-agent.d/secret_id

cat <<EOF> /etc/vault-agent.d/consul-ca-template.ctmpl
{{ with secret "${tpl_namespace}/pki/cert/ca" }}
{{ .Data.certificate }}
{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/consul-cert-template.ctmpl
{{ with secret "${tpl_namespace}/pki/issue/consul" "common_name=consul-server-0.server.aws-${tpl_region}.consul" "alt_names=consul-server-0.server.aws-${tpl_region}.consul,server.aws-${tpl_region}.consul,localhost" "ip_sans=127.0.0.1" "key_usage=DigitalSignature,KeyEncipherment" "ext_key_usage=ServerAuth,ClientAuth" }}
{{ .Data.certificate }}
{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/consul-key-template.ctmpl
{{ with secret "${tpl_namespace}/pki/issue/consul" "common_name=consul-server-0.server.aws-${tpl_region}.consul" "alt_names=consul-server-0.server.aws-${tpl_region}.consul,server.aws-${tpl_region}.consul,localhost" "ip_sans=127.0.0.1" "key_usage=DigitalSignature,KeyEncipherment" "ext_key_usage=ServerAuth,ClientAuth" }}
{{ .Data.private_key }}
{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/consul-acl-template.ctmpl
acl = {
  enabled        = true
  default_policy = "deny"
  down_policy   = "extend-cache"
  enable_token_persistence = true
  enable_token_replication = true
  tokens {
    master = {{ with secret "${tpl_namespace}/kv/consul" }}"{{ .Data.data.master_token }}"{{ end }}
    agent  = {{ with secret "${tpl_namespace}/kv/consul" }}"{{ .Data.data.master_token }}"{{ end }}
  }
}
encrypt = {{ with secret "${tpl_namespace}/kv/consul" }}"{{ .Data.data.gossip_key }}"{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/vault.hcl
pid_file = "/var/run/vault-agent-pidfile"
auto_auth {
  method "approle" {
      mount_path = "auth/approle"
			namespace = "${tpl_namespace}"
      config = {
          role_id_file_path = "/etc/vault-agent.d/role_id"
          secret_id_file_path = "/etc/vault-agent.d/secret_id"
					remove_secret_id_file_after_reading = false
      }
  }
	sink "file" {
		config = {
			path = "/etc/vault-agent.d/token"
		}
	}
}
template {
  source      = "/etc/vault-agent.d/consul-ca-template.ctmpl"
  destination = "/opt/consul/tls/ca-cert.pem"
  command     = "sudo service consul reload"
}
template {
  source      = "/etc/vault-agent.d/consul-cert-template.ctmpl"
  destination = "/opt/consul/tls/server-cert.pem"
  command     = "sudo service consul reload"
}
template {
  source      = "/etc/vault-agent.d/consul-key-template.ctmpl"
  destination = "/opt/consul/tls/server-key.pem"
  command     = "sudo service consul reload"
}
template {
  source      = "/etc/vault-agent.d/consul-acl-template.ctmpl"
  destination = "/etc/consul.d/acl.hcl"
  command     = "sudo service consul reload"
}
vault {
  address = "$${VAULT_ADDR}"
}
EOF
cat <<EOF > /etc/systemd/system/vault-agent.service
[Unit]
Description=Envoy
After=network-online.target
Wants=consul.service
[Service]
ExecStart=/usr/bin/vault agent -config=/etc/vault-agent.d/vault.hcl -log-level=debug
Restart=always
RestartSec=5
StartLimitIntervalSec=0
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable vault-agent.service
sudo systemctl start vault-agent.service
sleep 10

#consul
cat <<EOF> /etc/consul.d/server.json
{
  "datacenter": "aws-${tpl_region}",
  "primary_datacenter": "aws-${tpl_region}",
  "server": true,
  "bootstrap_expect": 1,
  "advertise_addr": "$${local_ipv4}",
  "data_dir": "/opt/consul/data",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "node_name": "consul-server-0",
  "ui": true,
  "connect": {
    "enable_mesh_gateway_wan_federation": true,
    "enabled": true
  }
}
EOF

#
#    "ca_provider": "vault",
#    "ca_config": {
#      "address": "$${VAULT_ADDR}",
#      "token": "$${CONNECT_TOKEN}",
#      "root_pki_path": "${tpl_namespace}/connect-root/",
#      "intermediate_pki_path": "${tpl_namespace}/connect-intermediate-east/"

cat <<EOF> /etc/consul.d/tls.json
{
  "verify_incoming": true,
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "ca_file": "/opt/consul/tls/ca-cert.pem",
  "cert_file": "/opt/consul/tls/server-cert.pem",
  "key_file": "/opt/consul/tls/server-key.pem",
  "auto_encrypt": {
    "allow_tls": true
  }
}
EOF
chown -R consul:consul /opt/consul/
chown -R consul:consul /etc/consul.d/
sudo systemctl enable consul.service
sudo systemctl start consul.service
sleep 10

#make sure the config was picked up
sudo service consul restart

exit 0
