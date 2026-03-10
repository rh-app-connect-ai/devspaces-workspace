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

    # echo "Send test message to RockatChat in $NAMESPACE"

    oc project $NAMESPACE

    # Obtain POD running RocketChat consumer
    POD=$(oc get pod -l app=r2k -o jsonpath='{.items[0].metadata.name}')

    # Simulate message from RocketChat to Webhook
    oc rsh $POD curl localhost:8080/webhook -d '{"text":"test message","timestamp":"dummy"}' -H "content-type: json"

    echo "Test message sent to: $NAMESPACE/$POD"
done

oc project $NS_TEST
echo "Switched back to host namespace $NS_TEST"

# Last message to send from hosting namespace (for testing)
# Obtain POD running RocketChat consumer
POD=$(oc get pod -l app=r2k -o jsonpath='{.items[0].metadata.name}')

# Simulate message from RocketChat to Webhook
oc rsh $POD curl localhost:8080/webhook -d '{"text":"test message","timestamp":"dummy"}' -H "content-type: json"

echo "Test message sent to: $NAMESPACE/$POD"

info "Done, all test messages sent."