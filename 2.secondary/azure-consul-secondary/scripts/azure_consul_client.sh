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

export VAULT_TOKEN=$(vault write -namespace=${tpl_namespace} -field=token auth/azure/login -field=token role="consul" \
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
  enable_token_replication = true
  tokens {
    agent  = "$${MASTER_TOKEN}"
    default = "$${MASTER_TOKEN}"
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

# install envoy
curl -L https://getenvoy.io/cli | bash -s -- -b /usr/local/bin
getenvoy fetch standard:1.16.0
cp /root/.getenvoy/builds/standard/*/linux_glibc/bin/envoy /usr/local/bin/envoy

mkdir -p /etc/envoy
cat <<EOF > /etc/envoy/consul.token
$${MASTER_TOKEN}
EOF

# make sure the config was picked up
sudo service consul restart

# license (every 5h 58m)
sudo crontab -l > consul
sudo echo "*/58 */5 * * * sudo service consul restart" >> consul
sudo crontab consul
sudo rm consul

# wait for consul leader


# wait for consul leader
while true
do
	RET=$(curl -s http://localhost:8500/v1/status/leader)
	echo "length = $${#RET}"
	[ $${#RET} -gt 2 ] && break
	echo "[ERROR] no consul leader"
	sleep 5
done


export CONSUL_HTTP_TOKEN=$${MASTER_TOKEN}
WEB_SERVICE_TOKEN=$(consul acl token create -format=json -service-identity=web:azure-${tpl_azure_region} | jq -r .SecretID)
SOCAT_SERVICE_TOKEN=$(consul acl token create -format=json -service-identity=socat:azure-${tpl_azure_region} | jq -r .SecretID)

logger "SOCAT_SERVICE_TOKEN: $${SOCAT_SERVICE_TOKEN}"
logger "WEB_SERVICE_TOKEN: $${WEB_SERVICE_TOKEN}"

# === scripts for socat ===

apt install socat

DEMO_SERVER_DIR=/home/ubuntu/proxy_demo_server
mkdir -p $${DEMO_SERVER_DIR}

cat <<EOF> $${DEMO_SERVER_DIR}/socat.hcl
service {
  name = "socat",
  id = "socat",
  port = 18181,
  token = "$${SOCAT_SERVICE_TOKEN}",
  connect {
    sidecar_service {}
  }
}
EOF

cat <<EOF> $${DEMO_SERVER_DIR}/service_defaults.hcl
Kind      = "service-defaults"
Name      = "socat"
Protocol  = "tcp"
EOF

echo "export CONSUL_HTTP_TOKEN=$${MASTER_TOKEN}" > $${DEMO_SERVER_DIR}/0.auth_to_consul.sh
cat <<EOF> $${DEMO_SERVER_DIR}/1.register_socat.sh
consul services register socat.hcl
consul config write service_defaults.hcl
EOF
echo 'consul connect envoy -sidecar-for socat -token-file /etc/envoy/consul.token -- -l debug'  > $${DEMO_SERVER_DIR}/2.start_envoy_proxy.sh
echo 'socat -v tcp-l:18181,fork exec:"/bin/cat"'  > $${DEMO_SERVER_DIR}/3.start_socat.sh

chmod 755 $${DEMO_SERVER_DIR}/*.sh
chown -R ubuntu:ubuntu $${DEMO_SERVER_DIR}

# === scripts for curl ===

DEMO_CLIENT_DIR=/home/ubuntu/proxy_demo_client
mkdir -p $${DEMO_CLIENT_DIR}

cat <<EOF> $${DEMO_CLIENT_DIR}/web.hcl
service {
  name = "web",
  id= "web",
  port = 8080,
  token = "$${WEB_SERVICE_TOKEN}",
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "socat",
            datacenter = "aws-${tpl_aws_region}",
            local_bind_port = 8181
          }
        ]
      }
    }
  }
}
EOF

cat <<EOF> $${DEMO_CLIENT_DIR}/service_defaults.hcl
Kind      = "service-defaults"
Name      = "web"
Protocol  = "tcp"
EOF

echo "export CONSUL_HTTP_TOKEN=$${MASTER_TOKEN}" > $${DEMO_CLIENT_DIR}/0.auth_to_consul.sh
cat <<EOF> $${DEMO_CLIENT_DIR}/1.register_web.sh
consul services register web.hcl
consul config write service_defaults.hcl
EOF
echo 'consul connect envoy -sidecar-for web -token-file /etc/envoy/consul.token -- -l debug'  > $${DEMO_CLIENT_DIR}/2.start_envoy_proxy.sh
echo 'consul intention create web socat' > $${DEMO_CLIENT_DIR}/3.create_intention.sh
echo 'curl --verbose 127.0.0.1:8181'  > $${DEMO_CLIENT_DIR}/4.send_get_request.sh
echo 'nc 127.0.0.1 8181'  > $${DEMO_CLIENT_DIR}/5.netcat.sh

chmod 755 $${DEMO_CLIENT_DIR}/*.sh
chown -R ubuntu:ubuntu $${DEMO_CLIENT_DIR}

exit 0
