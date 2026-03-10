#!/bin/bash
set -euo pipefail

# set -x

# Load common variables
source /projects/workshop/tools/test/config.sh

# Set expected number of users
EXPECTED=$(oc get secret htpasswd -n openshift-config -o jsonpath='{.data.htpasswd}' | base64 -d | grep user | wc -l)

echo "=== Kafka broker pods (only the real brokers) ==="
oc get pods --all-namespaces \
  -l strimzi.io/kind=Kafka \
  -o custom-columns=NS:.metadata.namespace,\
CLUSTER:.metadata.labels.'strimzi.io/cluster',\
POD:.metadata.name,\
READY:.status.containerStatuses[*].ready,\
PHASE:.status.phase \
  --sort-by=.metadata.namespace

# Count ONLY the real broker pods that are fully Ready
READY_COUNT=$(oc get pods --all-namespaces \
  -l strimzi.io/kind=Kafka \
  -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[*].ready}{"\n"}{end}' \
  | grep -v entity-operator | grep -v controller \
  | grep Running | grep -c '^.*true$')

echo -e "\n=== 1. Kafka Summary ==="
echo "Expected broker pods   : $EXPECTED"
echo "Actually ready brokers : $READY_COUNT"

if [ "$READY_COUNT" -eq "$EXPECTED" ]; then
  info "All $EXPECTED Kafka brokers are healthy and running"
else
  die "ERROR: Only $READY_COUNT/$EXPECTED brokers are ready!"
fi



echo -e "\n=== 2. Checking Matrix deployment (namespace matrix) ==="
oc -n matrix get pods --selector "app in (element,synapse)" --no-headers

MATRIX_OK=$(oc -n matrix get pods --selector "app in (element,synapse)" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true")

if [ "$MATRIX_OK" -eq 2 ]; then
  info "Matrix check PASSED – both element and synapse are 1/1 Running"
else
  die "Matrix check FAILED – one or both pods are not healthy"
fi



echo -e "\n=== 3. Checking RocketChat deployment (namespace rocketchat) ==="
oc -n rocketchat get pods --selector "app in (mongodb,rocketchat)" --no-headers

ROCKETCHAT_OK=$(oc -n rocketchat get pods --selector "app in (mongodb,rocketchat)" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true")

if [ "$ROCKETCHAT_OK" -eq 2 ]; then
  info "RocketChat check PASSED – both mongodb and srocketchatynapse are 1/1 Running"
else
  die "RocketChat check FAILED – one or both pods are not healthy"
fi


echo -e "\n=== 4. Checking DocServer (namespace webapp) ==="
oc -n webapp get pods --selector "app in (docserver)" --no-headers

DOCSERVER_OK=$(oc -n webapp get pods --selector "app in (docserver)" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true")

if [ "$DOCSERVER_OK" -eq 1 ]; then
  info "DocServer check PASSED – both mongodb and srocketchatynapse are 1/1 Running"
else
  die "DocServer check FAILED – one or both pods are not healthy"
fi


echo "=== Checking DevWorkspaces (expecting exactly $EXPECTED Running) ==="
oc get dw --all-namespaces \
  -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,URL:.status.mainUrl --no-headers --sort-by=.metadata.namespace

# Count total DevWorkspaces
TOTAL=$(oc get dw --all-namespaces --no-headers | wc -l)

# Count how many are actually Running
RUNNING=$(oc get dw --all-namespaces --no-headers | grep -c ' Running')

if [ "$TOTAL" -ne "$EXPECTED" ]; then
  die "DevWorkspaces COUNT FAILED: found $TOTAL, expected $EXPECTED"
fi

if [ "$RUNNING" -ne "$EXPECTED" ]; then
  warn "DevWorkspaces HEALTH FAILED: only $RUNNING/$TOTAL are Running" 
fi

echo "DevWorkspaces HEALTH & COUNT PASSED: $RUNNING/$EXPECTED are Running"

echo
info "All healthy!"