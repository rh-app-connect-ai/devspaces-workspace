#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

echo "Designated room for test: $TEST_ROOM"
echo "Namespace hosting the testing: $NS_TEST"

# Switch to host namespace for testing
oc project $NS_TEST

# Change direcory where test source code is located
cd /projects/workshop/tools/test/flows

# Undeploy master test flows
camel kubernetes delete --name m2k
camel kubernetes delete --name r2k
camel kubernetes delete --name k2m
camel kubernetes delete --name k2r

info "Deployments deleted from test namespace: $NS_TEST"