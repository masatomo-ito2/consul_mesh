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

# install az cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

#metadata
local_ipv4="$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-08-01&format=text")"
public_ipv4="$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-08-01&format=text")"

#vault
az login --identity
export VAULT_ADDR=${tpl_vault_addr}

mkdir -p /etc/vault-agent.d/
cat <<EOF> /etc/vault-agent.d/consul-ca-template.ctmpl
{{ with secret "pki/cert/ca" }}{{ .Data.certificate }}{{ end }}
EOF

cat <<EOF> /etc/vault-agent.d/consul-acl-template.ctmpl
acl = {
  enabled        = true
  default_policy = "deny"
  down_policy   = "extend-cache"
  enable_token_persistence = true
  enable_token_replication = true
  tokens {
    agent  = {{ with secret "kv/consul" }}"{{ .Data.data.master_token }}"{{ end }}
  }
}
encrypt = {{ with secret "kv/consul" }}"{{ .Data.data.gossip_key }}"{{ end }}
EOF

cat <<EOF> /etc/vault-agent.d/envoy-token-template.ctmpl
{{ with secret "kv/consul" }}{{ .Data.data.master_token }}{{ end }}
EOF

cat <<EOF> /etc/vault-agent.d/vault.hcl
pid_file = "/var/run/vault-agent-pidfile"
auto_auth {
  method "azure" {
		mount_path = "auth/azure"
		namespace  = "${tpl_namespace}"
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
  source      = "/etc/vault-agent.d/consul-acl-template.ctmpl"
  destination = "/etc/consul.d/acl.hcl"
  command     = "sudo service consul reload"
}
template {
  source      = "/etc/vault-agent.d/envoy-token-template.ctmpl"
  destination = "/etc/envoy/consul.token"
  command     = "sudo service envoy restart"
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
mkdir -p /opt/consul/tls/

cat <<EOF> /etc/consul.d/consul.hcl
datacenter = "azure-${tpl_azure_region}"
primary_datacenter = "aws-${tpl_aws_region}"
advertise_addr = "$${local_ipv4}"
client_addr = "0.0.0.0"
ui = true
connect = {
  enabled = true
}
data_dir = "/opt/consul/data"
log_level = "INFO"
ports = {
  grpc = 8502
}
retry_join = ["provider=azure tag_name=Env tag_value=consul-${tpl_env} subscription_id=${tpl_subscription_id}"]
EOF

cat <<EOF> /etc/consul.d/tls.hcl
ca_file = "/opt/consul/tls/ca-cert.pem"
verify_incoming = false
verify_outgoing = true
verify_server_hostname = true
auto_encrypt = {
  tls = true
}
EOF

chown -R consul:consul /opt/consul/
chown -R consul:consul /etc/consul.d/
sudo systemctl enable consul.service
sudo systemctl start consul.service
sleep 10

#license (every 5h 58m)
sudo crontab -l > consul
sudo echo "*/58 */5 * * * sudo service consul restart" >> consul
sudo crontab consul
sudo rm consul

#envoy mgw
curl -L https://getenvoy.io/cli | bash -s -- -b /usr/local/bin
getenvoy fetch standard:1.16.0
cp /root/.getenvoy/builds/standard/*/linux_glibc/bin/envoy /usr/local/bin/envoy
cat <<EOF > /etc/systemd/system/envoy.service
[Unit]
Description=Envoy
After=network-online.target
Wants=consul.service
[Service]
ExecStart=/usr/bin/consul connect envoy -expose-servers -gateway=mesh -register -service "mesh-gateway" -address "$${local_ipv4}:443" -wan-address "$${public_ipv4}:443" -token-file /etc/envoy/consul.token -- -l debug
Restart=always
RestartSec=5
StartLimitIntervalSec=0
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable envoy.service
sudo systemctl start envoy.service
sleep 10

#make sure the config was picked up
sudo service consul restart
sudo service envoy restart

exit 0
