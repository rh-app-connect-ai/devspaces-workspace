#!/bin/bash
set -euo pipefail

# Load common variables
source /projects/workshop/tools/test/config.sh

# Runs first Worspace fixing (failed state)
/projects/workshop/tools/test/ws-fix-failed.sh || exit $?

# Then checks for workspaces in "Stopped" status
echo "Searching for DevWorkspaces in Stopped phase across all namespaces..."

# Get list: namespace/name of only the Failed ones
STOPPED_DW=$(oc get dw --all-namespaces --no-headers --sort-by=.metadata.namespace | awk '$4 == "Stopped" {print $1 "/" $2}')

if [ -z "$STOPPED_DW" ]; then
  info "No Stopped DevWorkspaces found. Nothing to do."
  exit 0
fi

info "Found $(echo "$STOPPED_DW" | wc -l) Stopped DevWorkspace(s):"
echo "$STOPPED_DW"
echo

for DW in $STOPPED_DW; do
    NS=${DW%/*}
    NAME=${DW#*/}

    echo "Starting DevWorkspace: $NAME in namespace $NS"

    oc patch dw "$NAME" -n "$NS" --type=merge -p '{"spec":{"started":true}}' >/dev/null 2>&1
done

echo
info "All Stopped DevWorkspaces have been restarted."
echo "Current status:"
oc get dw --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase --sort-by=.metadata.namespace