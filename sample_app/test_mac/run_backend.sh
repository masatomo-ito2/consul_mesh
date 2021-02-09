#!/bin/bash 

EXE=backend_mac

export COLOR=blue
export MODE="Linux binary"
export TASK_ID=0
export LOCAL_PUBLIC_ADDR="127.0.0.1"
export PORT=10000
export VERSION=v1
export IMG_SRC="https://hashicorpjp.s3-ap-northeast-1.amazonaws.com/masa/Snapshots2021Jan_Nomad/${VERSION}.png"

../${EXE}
