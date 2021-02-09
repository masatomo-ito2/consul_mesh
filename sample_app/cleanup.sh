#!/bin/bash

killall backend
killall frontend
killall envoy

consul services deregister frontend.hcl
consul services deregister backend_v1.hcl
consul services deregister backend_v2.hcl

