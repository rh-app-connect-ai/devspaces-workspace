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

# --- 1. Kafka ---
logn "\n=== 1. Checking Kafka brokers ==="
if $VERBOSE; then
  oc get pods --all-namespaces \
    -l strimzi.io/kind=Kafka \
    -o custom-columns=NS:.metadata.namespace,\
CLUSTER:.metadata.labels.'strimzi.io/cluster',\
POD:.metadata.name,\
READY:.status.containerStatuses[*].ready,\
PHASE:.status.phase \
    --sort-by=.metadata.namespace | sort -V
fi

READY_COUNT=$(oc get pods --all-namespaces \
  -l strimzi.io/kind=Kafka \
  -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[*].ready}{"\n"}{end}' \
  | grep -v entity-operator | grep -v controller \
  | grep Running | grep -c '^.*true$' || true)

if [ "$READY_COUNT" -eq "$EXPECTED" ]; then
  pass "Kafka" "$READY_COUNT/$EXPECTED brokers ready"
else
  fail "Kafka" "$READY_COUNT/$EXPECTED brokers ready"
fi

# --- 2. Camel deployments ---
logn "\n=== 2. Checking Camel deployments ==="
CAMEL_APPS="m2k r2k k2m k2r"
CAMEL_FAIL=0
CAMEL_TOTAL=$((EXPECTED * 4))
CAMEL_FOUND=0

for i in $(seq 1 $EXPECTED); do
  NS="user${i}-devspaces"
  MISSING=""
  FOUND=""
  for APP in $CAMEL_APPS; do
    if oc get deployment "$APP" -n "$NS" --no-headers >/dev/null 2>&1; then
      FOUND="$FOUND $APP"
      CAMEL_FOUND=$((CAMEL_FOUND + 1))
    else
      MISSING="$MISSING $APP"
    fi
  done
  if $VERBOSE; then
    if [ -n "$MISSING" ]; then
      printf "  user%-4s \033[0;31mMISSING:%s\033[0m\n" "${i}" "${MISSING}"
    else
      printf "  user%-4s \033[0;32mOK\033[0m –%s\n" "${i}" "${FOUND}"
    fi
  fi
  if [ -n "$MISSING" ]; then
    CAMEL_FAIL=1
  fi
done

if [ "$CAMEL_FAIL" -eq 0 ]; then
  pass "Camel deployments" "$CAMEL_FOUND/$CAMEL_TOTAL across $EXPECTED users"
else
  fail "Camel deployments" "$CAMEL_FOUND/$CAMEL_TOTAL across $EXPECTED users"
fi

# --- 3. Matrix ---
logn "\n=== 3. Checking Matrix deployment ==="
if $VERBOSE; then
  oc -n matrix get pods --selector "app in (element,synapse)" --no-headers
fi

MATRIX_OK=$(oc -n matrix get pods --selector "app in (element,synapse)" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true" || true)

if [ "$MATRIX_OK" -eq 2 ]; then
  pass "Matrix" "element + synapse running"
else
  fail "Matrix" "$MATRIX_OK/2 pods running"
fi

# --- 4. RocketChat ---
logn "\n=== 4. Checking RocketChat deployment ==="
if $VERBOSE; then
  oc -n rocketchat get pods --selector "app in (mongodb,rocketchat)" --no-headers
fi

ROCKETCHAT_OK=$(oc -n rocketchat get pods --selector "app in (mongodb,rocketchat)" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true" || true)

if [ "$ROCKETCHAT_OK" -eq 2 ]; then
  pass "RocketChat" "mongodb + rocketchat running"
else
  fail "RocketChat" "$ROCKETCHAT_OK/2 pods running"
fi

# --- 5. Helpdesk ---
logn "\n=== 5. Checking Helpdesk deployment ==="
if $VERBOSE; then
  oc -n helpdesk get pods --selector "app in (helpdesk,helpdesk-db)" --no-headers
fi

HELPDESK_OK=$(oc -n helpdesk get pods --selector "app in (helpdesk,helpdesk-db)" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true" || true)

if [ "$HELPDESK_OK" -eq 2 ]; then
  pass "Helpdesk" "helpdesk + helpdesk-db running"
else
  fail "Helpdesk" "$HELPDESK_OK/2 pods running"
fi

# --- 6. Showroom ---
logn "\n=== 6. Checking Showroom deployment ==="
if $VERBOSE; then
  oc -n showroom get pods --selector "app.kubernetes.io/name=showroom" --no-headers
  oc -n showroom get pods --selector "app=docs-proxy" --no-headers
fi

SHOWROOM_POD=$(oc -n showroom get pods --selector "app.kubernetes.io/name=showroom" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true" || true)
PROXY_POD=$(oc -n showroom get pods --selector "app=docs-proxy" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true" || true)
SHOWROOM_OK=$((SHOWROOM_POD + PROXY_POD))

if [ "$SHOWROOM_OK" -eq 2 ]; then
  pass "Showroom" "showroom + docs-proxy running"
else
  fail "Showroom" "$SHOWROOM_OK/2 pods running"
fi

# --- 7. DocServer ---
logn "\n=== 7. Checking DocServer deployment ==="
if $VERBOSE; then
  oc -n showroom get pods --selector "app in (docserver)" --no-headers
fi

DOCSERVER_OK=$(oc -n showroom get pods --selector "app in (docserver)" --no-headers \
  -o jsonpath='{range .items[*]}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "Running	true" || true)

if [ "$DOCSERVER_OK" -eq 1 ]; then
  pass "DocServer" "docserver running"
else
  fail "DocServer" "not running"
fi

# --- 8. DevWorkspaces ---
logn "\n=== 8. Checking DevWorkspaces ==="
if $VERBOSE; then
  oc get dw --all-namespaces \
    -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,URL:.status.mainUrl --no-headers --sort-by=.metadata.namespace | sort -V
fi

TOTAL=$(oc get dw --all-namespaces --no-headers | wc -l | tr -d ' ')
RUNNING=$(oc get dw --all-namespaces --no-headers | grep -c ' Running' || true)

if [ "$TOTAL" -eq "$EXPECTED" ] && [ "$RUNNING" -eq "$EXPECTED" ]; then
  pass "DevWorkspaces" "$RUNNING/$EXPECTED running"
elif [ "$TOTAL" -ne "$EXPECTED" ]; then
  fail "DevWorkspaces" "found $TOTAL, expected $EXPECTED"
else
  warning "DevWorkspaces" "$RUNNING/$EXPECTED running"
fi

# --- Summary ---
echo ""
if [ "$FAILURES" -eq 0 ]; then
  if [ "$WARNINGS" -eq 0 ]; then
    info "All healthy!"
  else
    info "Success with warnings ($WARNINGS)"
  fi
else
  die "$FAILURES check(s) failed"
fi
