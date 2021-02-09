#!/bin/bash

consul connect envoy -sidecar-for frontend -token-file /etc/envoy/consul.token -- -l debug 
