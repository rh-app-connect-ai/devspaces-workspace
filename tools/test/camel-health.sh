#!/bin/bash
set -euo pipefail

source /projects/workshop/tools/test/config.sh

VERBOSE=false
if [ "${1:-}" = "-v" ]; then
  VERBOSE=true
fi

EXPECTED=$(oc get secret htpasswd -n openshift-config -o jsonpath='{.data.htpasswd}' | base64 -d | grep user | wc -l)

FAILURES=0
WARNINGS=0
CAMEL_APPS="m2k r2k k2m k2r"

pass() {
  printf "\033[0;32m✓\033[0m %-22s %s\n" "$1" "$2"
}

fail() {
  printf "\033[0;31m✗\033[0m %-22s %s\n" "$1" "$2"
  FAILURES=$((FAILURES + 1))
}

warning() {
  printf "\033[0;33m~\033[0m %-22s %s\n" "$1" "$2"
  WARNINGS=$((WARNINGS + 1))
}

log() {
  if $VERBOSE; then
    echo "$@"
  fi
}

logn() {
  if $VERBOSE; then
    echo -e "$@"
  fi
}

# --- Step 1: Scale up ---
logn "\n=== 1. Scaling up Camel deployments ==="
for i in $(seq 1 $EXPECTED); do
  NS="user${i}-devspaces"
  oc scale deployment $CAMEL_APPS --replicas=1 -n "$NS" > /dev/null 2>&1
  log "  user${i}: scaled up"
done
pass "Scale up" "all deployments set to replicas=1"

# --- Step 2: Wait for pods to be ready ---
logn "\n=== 2. Waiting for pods to be ready ==="
READY_FAIL=0

for i in $(seq 1 $EXPECTED); do
  NS="user${i}-devspaces"
  USER_OK=true
  USER_DETAIL=""
  for APP in $CAMEL_APPS; do
    if oc rollout status deployment/"$APP" -n "$NS" --timeout=120s > /dev/null 2>&1; then
      USER_DETAIL="$USER_DETAIL $APP"
    else
      USER_OK=false
      USER_DETAIL="$USER_DETAIL !$APP"
    fi
  done
  if $VERBOSE; then
    if $USER_OK; then
      printf "  user%-4s \033[0;32mOK\033[0m –%s\n" "${i}" "${USER_DETAIL}"
    else
      printf "  user%-4s \033[0;31mFAILED\033[0m –%s\n" "${i}" "${USER_DETAIL}"
    fi
  fi
  if ! $USER_OK; then
    READY_FAIL=1
  fi
done

if [ "$READY_FAIL" -eq 0 ]; then
  pass "Pods ready" "all Camel pods running across $EXPECTED users"
else
  fail "Pods ready" "some pods failed to start"
fi

# --- Step 3: Verify m2k Matrix streaming ---
logn "\n=== 3. Checking m2k Matrix streaming ==="
M2K_FAIL=0
M2K_TIMEOUT=60

for i in $(seq 1 $EXPECTED); do
  NS="user${i}-devspaces"
  POD=$(oc get pod -n "$NS" -l app=m2k -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "$POD" ]; then
    if $VERBOSE; then
      printf "  user%-4s \033[0;31mNO POD\033[0m\n" "${i}"
    fi
    M2K_FAIL=1
    continue
  fi
  FOUND=false
  for attempt in $(seq 1 $((M2K_TIMEOUT / 5))); do
    if oc logs "$POD" -n "$NS" 2>/dev/null | grep -q "Matrix HTTP Streaming started"; then
      FOUND=true
      break
    fi
    sleep 5
  done
  if $VERBOSE; then
    if $FOUND; then
      printf "  user%-4s \033[0;32mOK\033[0m – Matrix streaming started\n" "${i}"
    else
      printf "  user%-4s \033[0;31mFAILED\033[0m – streaming not detected after ${M2K_TIMEOUT}s\n" "${i}"
    fi
  fi
  if ! $FOUND; then
    M2K_FAIL=1
  fi
done

if [ "$M2K_FAIL" -eq 0 ]; then
  pass "m2k streaming" "all $EXPECTED users connected to Matrix"
else
  fail "m2k streaming" "some users failed to connect"
fi

# --- Step 4: Scale down ---
logn "\n=== 4. Scaling down Camel deployments ==="
for i in $(seq 1 $EXPECTED); do
  NS="user${i}-devspaces"
  oc scale deployment $CAMEL_APPS --replicas=0 -n "$NS" > /dev/null 2>&1
done

# --- Step 5: Wait for shutdown ---
logn "\n=== 5. Waiting for pods to terminate ==="
SHUTDOWN_FAIL=0
SHUTDOWN_TIMEOUT=180

for i in $(seq 1 $EXPECTED); do
  NS="user${i}-devspaces"
  ALL_DOWN=true
  for APP in $CAMEL_APPS; do
    if ! oc wait --for=delete pod -l app="$APP" -n "$NS" --timeout=${SHUTDOWN_TIMEOUT}s > /dev/null 2>&1; then
      REMAINING=$(oc get pod -l app="$APP" -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
      if [ "$REMAINING" -gt 0 ]; then
        ALL_DOWN=false
        if $VERBOSE; then
          printf "  user%-4s \033[0;31m%s still terminating\033[0m\n" "${i}" "$APP"
        fi
      fi
    fi
  done
  if $VERBOSE; then
    if $ALL_DOWN; then
      printf "  user%-4s \033[0;32mOK\033[0m – all pods terminated\n" "${i}"
    fi
  fi
  if ! $ALL_DOWN; then
    SHUTDOWN_FAIL=1
  fi
done

if [ "$SHUTDOWN_FAIL" -eq 0 ]; then
  pass "Scale down" "all pods terminated across $EXPECTED users"
else
  fail "Scale down" "some pods still terminating after ${SHUTDOWN_TIMEOUT}s"
fi

# --- Summary ---
echo ""
if [ "$FAILURES" -eq 0 ]; then
  if [ "$WARNINGS" -eq 0 ]; then
    info "All Camel deployments healthy!"
  else
    info "Success with warnings ($WARNINGS)"
  fi
else
  die "$FAILURES check(s) failed"
fi
