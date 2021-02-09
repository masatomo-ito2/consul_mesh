#!/bin/bash

consul connect envoy -sidecar-for backend-v1 -token-file /etc/envoy/consul.token -- -l debug > proxy_v1.log 2>&1 &

consul connect envoy -sidecar-for backend-v2 -token-file /etc/envoy/consul.token -- -l debug > proxy_v2.log 2>&1 &
