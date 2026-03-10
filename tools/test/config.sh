#!/bin/bash

# Pretty error function
die() {
  printf '\n\033[0;31mERROR:\033[0m %s\n\n' "$*" >&2
  exit 1
}

warn() {
  printf '\n\033[0;31mWARNING:\033[0m %s\n\n' "$*" >&2
}

info() {
  printf '\033[0;34mINFO:\033[0m %s\n' "$*"
}

info "Checking your privileges..."

# Method 1 – the most reliable (works in OCP 3.11 and 4.x)
if ! oc auth can-i '*' '*' --all-namespaces >/dev/null 2>&1; then
  CURRENT_USER=$(oc whoami)
  die "You ($CURRENT_USER) are NOT a cluster-admin.
       This script requires cluster-admin privileges.
       Please run it as a user that belongs to the cluster-admins group
       or use: oc login -u kubeadmin (or system:admin, etc.)"
fi

info "You are cluster-admin – continuing!"

# Extract the total number of users in the cluster
NUMBER=$(oc get secret htpasswd -n openshift-config -o jsonpath='{.data.htpasswd}' | base64 -d | grep user | wc -l)

# Range of User IDs where the apps will be deployed 
FIRST=1
LAST=$(( NUMBER - 1 ))

# This will be the room in RC and Matrix used for testing
TEST_ROOM="room$NUMBER"

# This is the test user designated to host the testing
TEST_USER=user$NUMBER

# This is the namespace chosen has host for testing
NS_TEST="user$NUMBER-devspaces"
