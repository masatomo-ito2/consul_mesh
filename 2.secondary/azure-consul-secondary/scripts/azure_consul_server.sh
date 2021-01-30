#!/bin/bash

set -x
exec > >(tee /tmp/tf-user-data.log|logger -t _bootstrap ) 2>&1

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

# install az cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

#metadata
local_ipv4=$(curl -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-08-01&format=text")

#vault
az login --identity
export VAULT_ADDR="${tpl_vault_addr}"
export VAULT_NAMESPACE=${tpl_vault_namespace}

export VAULT_TOKEN=$(vault write -field=token auth/azure/login -field=token role="consul" \
     jwt="$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -H Metadata:true | jq -r '.access_token')")
CONNECT_TOKEN=$(vault token create -field token -policy connect -period 8h -orphan)

logger "VAULT_TOKEN: $${VAULT_TOKEN}"


mkdir -p /etc/vault-agent.d/
mkdir -p /opt/consul/tls/

cat <<EOF> /etc/vault-agent.d/consul-ca-template.ctmpl
{{ with secret "${tpl_vault_namespace}/pki/cert/ca" }}
{{ .Data.certificate }}
{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/consul-cert-template.ctmpl
{{ with secret "${tpl_vault_namespace}/pki/issue/consul" "common_name=consul-server-0.server.azure-${tpl_azure_region}.consul" "alt_names=consul-server-0.server.azure-${tpl_azure_region}.consul,server.azure-${tpl_azure_region}.consul,localhost" "ip_sans=127.0.0.1" "key_usage=DigitalSignature,KeyEncipherment" "ext_key_usage=ServerAuth,ClientAuth" }}
{{ .Data.certificate }}
{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/consul-key-template.ctmpl
{{ with secret "${tpl_vault_namespace}/pki/issue/consul" "common_name=consul-server-0.server.azure-${tpl_azure_region}.consul" "alt_names=consul-server-0.server.azure-${tpl_azure_region}.consul,server.azure-${tpl_azure_region}.consul,localhost" "ip_sans=127.0.0.1" "key_usage=DigitalSignature,KeyEncipherment" "ext_key_usage=ServerAuth,ClientAuth" }}
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
    agent  = {{ with secret "${tpl_vault_namespace}/kv/consul" }}"{{ .Data.data.master_token }}"{{ end }}
    replication = {{ with secret "${tpl_vault_namespace}/kv/consul" }}"{{ .Data.data.replication_token }}"{{ end }}
  }
}
encrypt = {{ with secret "${tpl_vault_namespace}/kv/consul" }}"{{ .Data.data.gossip_key }}"{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/vault.hcl
pid_file = "/var/run/vault-agent-pidfile"
auto_auth {
  method "azure" {
		mount_path = "auth/azure"
		namespace  = "${tpl_vault_namespace}"
		config = {
				role = "consul"
				resource = "https://management.azure.com/"
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

#config
cat <<EOF> /etc/consul.d/server.json
{
  "datacenter": "azure-${tpl_azure_region}",
  "primary_datacenter": "aws-${tpl_aws_region}",
  "server": true,
  "bootstrap_expect": 1,
  "advertise_addr": "$${local_ipv4}",
  "data_dir": "/opt/consul/data",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "node_name": "consul-server-0",
  "ui": true,
  "primary_gateways" : ["${tpl_primary_wan_gateway}"],
  "connect": {
    "enable_mesh_gateway_wan_federation": true,
    "enabled": true
  }
}
EOF
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
sleep 15

# make sure the config was picked up
sudo service consul restart

# wait for consul to boot up
sleep 30


exit 0
