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

#vault
az login --identity
export VAULT_ADDR="${tpl_vault_addr}"
export VAULT_NAMESPACE="${tpl_namespace}"

export VAULT_TOKEN=$(vault write -field=token auth/azure/login -field=token role="consul" \
     jwt="$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -H Metadata:true | jq -r '.access_token')")
CONNECT_TOKEN=$(vault token create -field token -policy connect -period 8h -orphan) # not used. can be deleted.

logger "VAULT_TOKEN: $${VAULT_TOKEN}"
logger "CONNECT_TOKEN: $${CONNECT_TOKEN}"

# Vault CA cert
mkdir -p /opt/consul/tls/
vault read -field=certificate pki/cert/ca > /opt/consul/tls/ca-cert.pem

# Consul ACL
MASTER_TOKEN=$(vault kv get -field=master_token kv/consul)
GOSSIP_KEY=$(vault kv get -field=gossip_key kv/consul)
cat <<EOF> /etc/consul.d/acl.hcl
acl = {
  enabled        = true
  default_policy = "deny"
  down_policy    = "extend-cache"
  enable_token_persistence = true
  tokens {
    agent  = "$${MASTER_TOKEN}"
  }
}
encrypt = "$${GOSSIP_KEY}"
EOF

# Consul configuration
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

# Consul TLS
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

#license
sudo crontab -l > consul
sudo echo "*/28 * * * * sudo service consul restart" >> consul
sudo crontab consul
sudo rm consul

# install envoy
curl -L https://getenvoy.io/cli | bash -s -- -b /usr/local/bin
getenvoy fetch standard:1.16.0
cp /root/.getenvoy/builds/standard/*/linux_glibc/bin/envoy /usr/local/bin/envoy

mkdir -p /etc/envoy
cat <<EOF > /etc/envoy/consul.token
$${MASTER_TOKEN}
EOF

#make sure the config was picked up
sudo service consul restart

# sample app

sleep 15

export CONSUL_HTTP_TOKEN=$${MASTER_TOKEN}
SOCAT_SERVICE_TOKEN=$(consul acl token create -format=json -service-identity=socat:azure-${tpl_azure_region} | jq -r .SecretID)

cat <<EOF> /etc/consul.d/socat.hcl
service {
  name = "socat",
  port = 8181,
  token = "$${SOCAT_SERVICE_TOKEN}",
  connect {
    sidecar_service {}
  }
}
EOF

consul reload

exit 0
