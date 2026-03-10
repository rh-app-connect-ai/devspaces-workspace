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


# Where to call (change namespace if needed)
DOCSERVER_URL="http://docserver.webapp.svc:80"

# Fetch token,userId in one shot
echo "Fetching Rocket.Chat credentials from $DOCSERVER_URL ..."
RESPONSE=$(curl -sSf "$DOCSERVER_URL/configuration/rocketchat/$TEST_USER")   # -s silent, -S show errors, -f fail on HTTP errors

echo "response was: $RESPONSE"

# Split the response on the comma
IFS=',' read -r ROCKETCHAT_TOKEN ROCKETCHAT_USERID <<< "$RESPONSE"

# Sanity check
if [[ -z "$ROCKETCHAT_TOKEN" || -z "$ROCKETCHAT_USERID" ]]; then
  echo "ERROR: Invalid response from docserver: '$RESPONSE'" >&2
  exit 1
fi

echo "Got token: ${ROCKETCHAT_TOKEN:0:10}... and userId: $ROCKETCHAT_USERID"


# Fetch token,userId in one shot
echo "Fetching Matrix credentials from $DOCSERVER_URL ..."
RESPONSE=$(curl -sSf "$DOCSERVER_URL/configuration/matrix/$TEST_USER")   # -s silent, -S show errors, -f fail on HTTP errors

echo "response was: $RESPONSE"

# Split the response on the comma
IFS=',' read -r MATRIX_TOKEN MATRIX_ROOM <<< "$RESPONSE"

# Sanity check
if [[ -z "$MATRIX_TOKEN" || -z "$MATRIX_ROOM" ]]; then
  echo "ERROR: Invalid response from docserver: '$RESPONSE'" >&2
  exit 1
fi

echo "Got token: $MATRIX_TOKEN and userId: $MATRIX_ROOM"

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