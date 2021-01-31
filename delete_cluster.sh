#!/bin/bash

pushd .

cd 2.secondary
terraform destroy -auto-approve

popd
pushd .

cd 1.primary
terraform destroy -auto-approve


