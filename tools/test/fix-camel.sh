#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

# ------------------- Argument validation -------------------
if [ $# -ne 1 ]; then
  echo "ERROR: Exactly one argument required"
  echo "Usage: $0 <user-number> | all"
  echo "Examples:"
  echo "  $0 59"
  echo "  $0 all"
  exit 1
fi

ARG="$1"

if [[ "$ARG" == "all" ]]; then
  echo "Running for ALL users "
  FROM=$FIRST
  TO=$(( LAST + 1 ))
else
  FROM=$ARG
  TO=$ARG
fi

echo "Running from: $FROM, to $TO"
# exit

# Run health check
source /projects/workshop/tools/test/health.sh


# echo "All args: $@"

rm -rf /tmp/workshop
mkdir -p /tmp/workshop/log

TOKEN=$(oc whoami -t)
SERVER=$(oc whoami --show-server)





# === 1. Get ONLY the Running DevWorkspaces (once) ===
mapfile -t RUNNING_DW < <(
  oc get dw --all-namespaces \
    -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase \
    --no-headers --sort-by=.metadata.namespace |
    awk '$3 == "Running" {print $1}'   # prints only the namespace (e.g. user59-devspaces)
)

# Convert array to associative array for O(1) lookup
declare -A IS_RUNNING
for ns in "${RUNNING_DW[@]}"; do
  IS_RUNNING["$ns"]=1
done

info "Found ${#RUNNING_DW[@]} running DevWorkspaces (others will be skipped)"




# Iterate over range of namespaces where to deploy the test flows
# for i in $(seq "$FIRST" "$LAST"); do
# for i in $(seq "58" "60" ); do
for i in $(seq $FROM $TO); do

    echo "executing command on user$i"

    # Target namespace
    NAMESPACE=user$i-devspaces

    # Skip if DevWorkspace is not Running
    if [[ -z "${IS_RUNNING[$NAMESPACE]:-}" ]]; then
      echo "SKIPPED" > /tmp/workshop/log/user$i.txt
      echo "Skipping user$i – DevWorkspace not Running"
      continue
    fi

    POD=$(oc get pods -o name -n $NAMESPACE | grep workspace)

    # Execute command. Note 'bash' consumes arg0
    oc exec -i -n $NAMESPACE $POD -- \
    bash -c '

    set -e

    echo "this is: $DEVWORKSPACE_NAMESPACE"
    source ~/.bashrc
    
    echo "checking jbang..."
    jbang version

    echo "checking camel jbang..."
    if ! command -v camel &> /dev/null; then
        echo "camel command not found - installing Camel JBang..."
        jbang trust add https://github.com/apache/camel/
        jbang app install -Dcamel.jbang.version=4.16.0 camel@apache/camel
        jbang camel@apache/camel plugin add kubernetes
        camel version  # optional: show version again after install
        echo "FIXED"
    else
        camel version
        echo "SUCCESS"
    fi

    ' _ $TOKEN $SERVER \
    > /tmp/workshop/log/user$i.txt 2>&1 &
    # "_" is the dummy $0, then real args can be used.

    # echo "Now this is: $DEVWORKSPACE_NAMESPACE"
done

info "All jobs started – waiting for all background oc exec processes to finish..."
wait  # Waits for all the detached proceses to finish
info "All background jobs have completed."

source report.sh