#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

# restart-failed-devworkspaces.sh
# Restart every DevWorkspace that is currently in Failed phase

echo "Searching for DevWorkspaces in Failed phase across all namespaces..."

# Get list: namespace/name of only the Failed ones
FAILED_DW=$(oc get dw --all-namespaces --no-headers --sort-by=.metadata.namespace | awk '$4 == "Failed" {print $1 "/" $2}')

if [ -z "$FAILED_DW" ]; then
  info "No Failed DevWorkspaces found. Nothing to do."
  exit 0
fi

info "Found $(echo "$FAILED_DW" | wc -l) Failed DevWorkspace(s):"
echo "$FAILED_DW"
echo

for DW in $FAILED_DW; do
    NS=${DW%/*}
    NAME=${DW#*/}

    echo "Restarting DevWorkspace: $NAME in namespace $NS"

    oc patch dw "$NAME" -n "$NS" --type=merge -p '{"spec":{"started":true}}' >/dev/null 2>&1
done

echo
info "All Failed DevWorkspaces have been restarted."
echo "Current status:"
oc get dw --all-namespaces -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase --sort-by=.metadata.namespace