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

#vault
export VAULT_ADDR="${tpl_vault_addr}"
export VAULT_NAMESPACE="${tpl_namespace}"

vault login -method=userpass username=admin password=${tpl_admin_passwd}

# Vault CA cert
mkdir -p /opt/consul/tls/
vault read -field=certificate pki/cert/ca > /opt/consul/tls/ca-cert.pem

# Consul ACL
MASTER_TOKEN=$(vault kv get -field=master_token kv/consul)
GOSSIP_KEY=$(vault kv get -field=gossip_key kv/consul)
cat <<EOF> etc/consul.d/acl.hcl
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
datacenter = "aws-${tpl_region}"
primary_datacenter = "aws-${tpl_region}"
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
retry_join = ["provider=aws tag_key=Env tag_value=consul-${tpl_env}"]
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

#license (every 5h 58m)
sudo crontab -l > consul
sudo echo "*/58 */5 * * * sudo service consul restart" >> consul
sudo crontab consul
sudo rm consul

# Demo preparation

export CONSUL_HTTP_TOKEN=$${MASTER_TOKEN}
WEB_SERVICE_TOKEN=$(consul acl token create -format=json -service-identity=web:aws-${tpl_region} | jq -r .SecretID)
SOCAT_SERVICE_TOKEN=$(consul acl token create -format=json -service-identity=socat:aws-${tpl_region} | jq -r .SecretID)

logger "WEB_SERVICE_TOKEN: $${SOCAT_WEB_TOKEN}"
logger "SOCAT_SERVICE_TOKEN: $${SOCAT_SERVICE_TOKEN}"

# === scripts for socat ===

apt install socat

DEMO_SOCAT_DIR=/home/ubuntu/proxy_demo_socat
mkdir -p $${DEMO_SOCAT_DIR}

cat <<EOF> $${DEMO_SOCAT_DIR}/socat.hcl
service {
  name = "socat",
  port = 18181,
  token = "$${SOCAT_SERVICE_TOKEN}",
  connect {
    sidecar_service {}
  }
}
EOF

echo "export CONSUL_HTTP_TOKEN=$${MASTER_TOKEN}" > $${DEMO_SOCAT_DIR}/0.auth_to_consul.sh
echo 'consul services register socat.hcl' > $${DEMO_SOCAT_DIR}/1.register_socat.sh
echo 'consul connect envoy -sidecar-for socat -token-file /etc/envoy/consul.token -- -l debug'  > $${DEMO_SOCAT_DIR}/2.start_envoy_proxy.sh
echo 'socat -v tcp-l:18181,fork exec:"/bin/cat"'  > $${DEMO_SOCAT_DIR}/3.start_socat.sh

chmod 755 $${DEMO_SOCAT_DIR}/*.sh
chown -R ubuntu:ubuntu $${DEMO_SOCAT_DIR}

# === scripts for curl ===

DEMO_CURL_DIR=/home/ubuntu/proxy_demo_curl
mkdir -p $${DEMO_CURL_DIR}

cat <<EOF> $${DEMO_CURL_DIR}/web.hcl
service {
  name = "web",
  port = 8080,
  token = "$${WEB_SERVICE_TOKEN}",
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "socat",
            datacenter = "azure-${tpl_azure_region}",
            local_bind_port = 8181
          }
        ]
      }
    }
  }
}
EOF

echo "export CONSUL_HTTP_TOKEN=$${MASTER_TOKEN}" > $${DEMO_CURL_DIR}/0.auth_to_consul.sh
echo 'consul services register web.hcl' > $${DEMO_CURL_DIR}/1.register_web.sh
echo 'consul connect envoy -sidecar-for web -token-file /etc/envoy/consul.token -- -l debug'  > $${DEMO_CURL_DIR}/2.start_envoy_proxy.sh
echo 'consul intention create web socat' > $${DEMO_CURL_DIR}/3.create_intention.sh
echo 'curl --verbose 127.0.0.1:8181'  > $${DEMO_CURL_DIR}/4.send_get_request.sh

chmod 755 $${DEMO_CURL_DIR}/*.sh
chown -R ubuntu:ubuntu $${DEMO_CURL_DIR}

exit 0
