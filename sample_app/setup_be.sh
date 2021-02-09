#!/bin/bash

#  script to 
#   - [done] create service definition file (.hcl)
#   - [done] create ACL tokens for service
#   - [done] register service

AWS_DC=aws-ap-northeast-1
AZURE_DC=azure-japaneast

# App  settings
V1_PORT=10001
V2_PORT=10002

#echo ">>>$1<<<"

case $1 in
	aws)
		echo "aws"
		SOURCE_DC=$AWS_DC
		TARGET_DC=$AZURE_DC
		LOCAL_PRIVATE_ADDR=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
		LOCAL_PUBLIC_ADDR=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
		;;
	azure)
		echo "aws"
		SOURCE_DC=$AZURE_DC
		TARGET_DC=$AWS_DC
		LOCAL_PRIVATE_ADDR=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-08-01&format=text")
		LOCAL_PUBLIC_ADDR=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-08-01&format=text")
		;;
	*)
		echo "must suppoly arg (aws|azure)"
		exit
esac

BE_ACL_TOKEN=$(consul acl token create -format=json -service-identity=backend:${SOURCE_DC} | jq -r .SecretID)

# ==== Backend v1 =====
cat <<EOF> backend_v1.hcl
service {
  name = "backend",
  id= "backend-v1",
  port = ${V1_PORT},
  token = "${BE_ACL_TOKEN}",
  connect {
    sidecar_service {}
  }
  meta {
    version = "v1"
  }
  tags = [ "v1" ]
}
EOF

consul services register backend_v1.hcl

# ==== Backend v2 =====
cat <<EOF> backend_v2.hcl
service {
  name = "backend",
  id= "backend-v2",
  port = ${V2_PORT},
  token = "${BE_ACL_TOKEN}",
  connect {
    sidecar_service {}
  }
  meta {
    version = "v2"
  }
  tags = [ "v2" ]
}
EOF

consul services register backend_v2.hcl

# ==== Service resolver ======

cat  <<EOF> service_resolver_backend.sh
Kind = "service-resolver"
Name = "backend"
DefaultSubset = "v1"
Subsets = {
  "v1" = {
    Filter = "Service.Meta.version == v1"
  }
  "v2" = {
    Filter = "Service.Meta.version == v2"
  }
}
EOF

consul config write service_resolver_backend.sh

# ==== Service Router ====

cat  <<EOF> service_router_backend.sh
Kind = "service-router"
Name = "backend"

Routes = [
	{
		Match {
			HTTP {
				QueryParam = [
					{
						Name = "version"
						Exact = "v1"
					},
				]
			}
		}
		Destination {
			Service = "backend"
			ServiceSubset = "v1"
		}
	},
	{
		Match {
			HTTP {
				QueryParam = [
					{
						Name = "version"
						Exact = "v2"
					},
				]
			}
		}
		Destination {
			Service = "backend"
			ServiceSubset = "v2"
		}
	},
	{
		Match {
			HTTP {
				PathExact = "/v1"
			}
		}
		Destination {
			Service = "backend"
			ServiceSubset = "v1"
		}
	},
	{
		Match {
			HTTP {
				PathExact = "/v2"
			}
		}
		Destination {
			Service = "backend"
			ServiceSubset = "v2"
		}
	},
]
EOF

consul config write service_router_backend.sh

# ==== Service Splitter ======

cat  <<EOF> service_splitter_backend.sh
kind = "service-splitter"
name = "backend"
splits = [
	{
		weight = 50
		service_subset = "v1"
	},
	{
		weight = 50
		service_subset = "v2"
	}
]
EOF

consul config write service_splitter_backend.sh


# Run back ground app

export COLOR=blue
export MODE="Linux binary"
export TASK_ID=0
export ADDR=${LOCAL_PRIVATE_ADDR}
export PORT=${V1_PORT}
export VERSION=v1
export PUBLIC_IP=${LOCAL_PUBLIC_ADDR}
export IMG_SRC="https://hashicorpjp.s3-ap-northeast-1.amazonaws.com/masa/Snapshots2021Jan_Nomad/${VERSION}.png" 

echo "Starting backend task ${VERSION} at port ${V1_PORT}"
./backend > backend_v1.log 2>&1 &

# run v2
export COLOR=blue
export MODE="Linux binary"
export TASK_ID=0
export ADDR=${LOCAL_PRIVATE_ADDR}
export PORT=${V2_PORT}
export VERSION=v2
export PUBLIC_IP=${LOCAL_PUBLIC_ADDR}
export IMG_SRC="https://hashicorpjp.s3-ap-northeast-1.amazonaws.com/masa/Snapshots2021Jan_Nomad/${VERSION}.png" 

echo "Starting backend task ${VERSION} at port ${V2_PORT}"
./backend > backend_v2.log 2>&1 &
