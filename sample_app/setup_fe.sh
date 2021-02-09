#!/bin/bash

#  script to 
#   - [done] create service definition file (.hcl)
#   - [done] create ACL tokens for service
#   - [done] register service

AWS_DC=aws-ap-northeast-1
AZURE_DC=azure-japaneast

#echo ">>>$1<<<"

case $1 in
	aws)
		SOURCE_DC=$AWS_DC
		TARGET_DC=$AZURE_DC
		;;
	azure)
		SOURCE_DC=$AZURE_DC
		TARGET_DC=$AZURE_DC
		;;
	*)
		echo "must suppoly arg (aws|azure)"
		exit
esac

# ==== Frontend =======
FE_ACL_TOKEN=$(consul acl token create -format=json -service-identity=frontend:${SOURCE_DC} | jq -r .SecretID)

cat <<EOF> frontend.hcl
service {
  name = "frontend",
  id= "frontend",
  port = 8080,
  token = "${FE_ACL_TOKEN}",
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "backend",
            datacenter = "${TARGET_DC}",
            local_bind_port = 9999
          }
        ]
      }
    }
  }
}
EOF

consul services register frontend.hcl

# Create intention
consul intention create frontend backend

# Run app

export PORT=8080  # fontend app run at
export UPSTREAM_URL="http://127.0.0.1:9999"   # localhost proxy

echo "starting front end at port ${PORT}"
./frontend > frontend.log 2>&1 &
