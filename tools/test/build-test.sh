#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

# Run health check
source /projects/workshop/tools/test/health.sh

echo "Designated room for test: $TEST_ROOM"
echo "Namespace hosting the testing: $NS_TEST"

# Ensure we build the flows in the test namespaces
oc project $NS_TEST

# Build flows from folder where source code is located
cd /projects/workshop/tools/test/flows

# Read credentials from lab-config Secret
CACHE="/tmp/lab-config.cache"
if [ ! -s "$CACHE" ]; then
  oc get secret lab-config -o json | jq -r '.data["config"]' | base64 -d > "$CACHE"
fi

ROCKETCHAT_TOKEN=$(grep '^rocketchat_token=' "$CACHE" | cut -d'=' -f2-)
ROCKETCHAT_USERID=$(grep '^rocketchat_userid=' "$CACHE" | cut -d'=' -f2-)
MATRIX_TOKEN=$(grep '^matrix_token=' "$CACHE" | cut -d'=' -f2-)
MATRIX_ROOM=$(grep '^matrix_room=' "$CACHE" | cut -d'=' -f2-)

echo "Got RC token: ${ROCKETCHAT_TOKEN:0:10}... and userId: $ROCKETCHAT_USERID"
echo "Got Matrix token: ${MATRIX_TOKEN:0:10}... and room: $MATRIX_ROOM"

cat > application.properties <<EOF
# Matrix credentials
matrix.token=$MATRIX_TOKEN
matrix.room=$MATRIX_ROOM

# Rocket.Chat credentials
rocketchat.token=$ROCKETCHAT_TOKEN
rocketchat.userid=$ROCKETCHAT_USERID
EOF

camel kubernetes run m2k/* \
application.properties \
--name m2k \
--property quarkus.config.locations=application.properties \
--local-kamelet-dir /projects/workshop/support/kamelets \
--cluster-type openshift

camel kubernetes run k2r/* \
application.properties \
--name k2r \
--property quarkus.config.locations=application.properties \
--local-kamelet-dir /projects/workshop/support/kamelets \
--cluster-type openshift \
--env RC_ROOM=$TEST_ROOM

camel kubernetes run r2k/* \
application.properties \
--name r2k \
--property quarkus.config.locations=application.properties \
--local-kamelet-dir /projects/workshop/support/kamelets \
--cluster-type openshift

camel kubernetes run k2m/* \
application.properties \
--name k2m \
--property quarkus.config.locations=application.properties \
--local-kamelet-dir /projects/workshop/support/kamelets \
--cluster-type openshift

info "Flows have been built and deployed in: $NS_TEST"
info "Done!"
