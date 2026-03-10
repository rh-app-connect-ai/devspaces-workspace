#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

echo "Designated room for test: $TEST_ROOM"
echo "Namespace hosting the testing: $NS_TEST"


# Iterate over range of namespaces where to deploy the test flows
for i in $(seq "$FIRST" "$LAST"); do

    # Target namespace
    NAMESPACE=user$i-devspaces

    # Switch to target namespace
    oc project $NAMESPACE

    # Undeploy test flows
    oc delete deployment/m2k --ignore-not-found
    oc delete deployment/r2k --ignore-not-found
    oc delete deployment/k2m --ignore-not-found
    oc delete deployment/k2r --ignore-not-found

    echo "Flows undeployed from: $NAMESPACE"
done


# Wait until no pods exist outside user60-devspaces with that label
until [ -z "$(oc get pods --all-namespaces --selector=group=org.example.project --sort-by=.metadata.namespace --no-headers \
    | grep -v $NS_TEST | grep -v webapp)" ]; do
  REMAINING=$(oc get pods --all-namespaces --selector=group=org.example.project --sort-by=.metadata.namespace --no-headers \
               | grep -v $NS_TEST | grep -v webapp | wc -l)
  echo "Still waiting... $REMAINING unwanted pods remain (outside $NS_TEST and webapp)"
  sleep 5
done

info "Cleanup complete – only $NS_TEST (and webapp) pods remain with the label"
oc get pods --all-namespaces --selector=group=org.example.project --sort-by=.metadata.namespace

oc project $NS_TEST
echo "Switched back to host namespace $NS_TEST"
info "Test apps deleted from all users."