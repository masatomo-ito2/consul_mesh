#!/bin/bash

pushd .

cd 1.primary
terraform apply -auto-approve

popd
pushd .

cd 2.secondary
terraform apply -auto-approve

