#!/bin/bash
set -euo pipefail

# set -x

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




# 1. Get all worker nodes
mapfile -t ALL_NODES < <(
  oc get nodes -l node-role.kubernetes.io/worker --no-headers -o name | cut -d/ -f2
)

echo "Found ${#ALL_NODES[@]} worker nodes total"


# Deploys IM instance with parameters
imDeploy() {
  oc apply -f - <<EOF
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: ${APP}
  labels:
    app: ${APP}
    app.kubernetes.io/part-of: ${GROUP}
    app.kubernetes.io/version: 1.0-SNAPSHOT
    app.kubernetes.io/runtime: camel
    provider: jkube
    app.openshift.io/runtime: camel
    app.kubernetes.io/managed-by: jkube
    version: 1.0-SNAPSHOT
    app.kubernetes.io/name: ${APP}
    group: ${GROUP}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${APP}
      app.kubernetes.io/managed-by: jkube
      app.kubernetes.io/name: ${APP}
      app.kubernetes.io/part-of: ${GROUP}
      group: ${GROUP}
      provider: jkube
  template:
    metadata:
      name: ${APP}
      creationTimestamp: null
      labels:
        app: ${APP}
        app.kubernetes.io/managed-by: jkube
        app.kubernetes.io/name: ${APP}
        app.kubernetes.io/part-of: ${GROUP}
        app.kubernetes.io/version: 1.0-SNAPSHOT
        group: ${GROUP}
        provider: jkube
        version: 1.0-SNAPSHOT
    spec:
      containers:
        - resources: {}
          readinessProbe:
            httpGet:
              path: /observe/health/ready
              port: 9876
              scheme: HTTP
            initialDelaySeconds: 5
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          terminationMessagePath: /dev/termination-log
          name: ${APP}
          livenessProbe:
            httpGet:
              path: /observe/health/live
              port: 9876
              scheme: HTTP
            initialDelaySeconds: 10
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          env:
            - name: KUBERNETES_NAMESPACE
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.namespace
            - name: RC_ROOM
              value: ${RC_ROOM}
          securityContext:
            privileged: false
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          imagePullPolicy: IfNotPresent
          startupProbe:
            httpGet:
              path: /observe/health/started
              port: 9876
              scheme: HTTP
            initialDelaySeconds: 5
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          terminationMessagePolicy: File
          image: ${IMAGE}
      ${NODE_NAME}
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  revisionHistoryLimit: 2
  progressDeadlineSeconds: 600
EOF
}

#################################
# PHASE 1: Deploy Mocks
#################################
# Deploy mock apps in all worker nodes to ensure all nodes authenticate in the image registry
# This ensures success in scheduling pods in all nodes while deploying apps in all users
for GROUP in m2k r2k k2m k2r; do
  info "=== Deployment mocks for $GROUP in all nodes ==="

  IMAGE=$(oc get deployment $GROUP -o jsonpath='{.spec.template.spec.containers[0].image}')
  info "$GROUP image: $IMAGE"

  RC_ROOM=DUMMY

  # Loop through all nodes with a counter
  for i in "${!ALL_NODES[@]}"; do
    node="${ALL_NODES[$i]}"
    
    NODE_NAME="nodeName: $node"

    # Pick the app name using the counter (loops back if more nodes than apps)
    APP="mock$i-$GROUP"
    
    imDeploy
  done
done

# Ensure all mocks running on all nodes
oc wait --for=condition=Ready pod --selector 'group in (m2k,r2k,k2m,k2r)' --timeout=30s



####################################
# PHASE 2: Deploy Apps in all users
####################################

# Apps in the exact order you want to process them
APPS=(m2k r2k k2m k2r)

# Collect all images upfront, keeping the same order
declare -a IMAGES

for APP in "${APPS[@]}"; do
    # info "=== Gathering image for $APP ==="
    IMAGE=$(oc get deployment "$APP" -n "$NS_TEST" \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "$IMAGE" == "NOT_FOUND" ]]; then
        error "Deployment $APP not found or has no image in namespace $NS_TEST"
        exit 1
    fi
    
    IMAGES+=("$IMAGE")          # append to array
    info "$APP image collected: $IMAGE"
done


# Iterate over range of namespaces where to deploy the test flows
for i in $(seq "$FIRST" "$LAST"); do

  # Target namespace
  NAMESPACE=user$i-devspaces

  echo "deploying in $NAMESPACE"

  oc project $NAMESPACE

  GROUP="org.example.project"
  NODE_NAME=""
  RC_ROOM=$TEST_ROOM


  # Now deploy, using the pre-collected images in the same order
  for i in "${!APPS[@]}"; do
      APP="${APPS[$i]}"
      IMAGE="${IMAGES[$i]}"

      # info "=== Deploying $APP ==="
      # info "$APP image: $IMAGE"

      # your existing deployment function
      imDeploy
  done
  echo "Done deployment in $NAMESPACE"
done


####################################
# PHASE 3: Delete Mocks
####################################
oc project $NS_TEST

echo "Switched back to host namespace $NS_TEST"

oc delete deploy --selector 'group in (m2k,r2k,k2m,k2r)'


#########################################
# PHASE 4: Check health of deployed apps
#########################################
info "Waiting for all pods in all users to be Ready..."
if oc wait --for=condition=Ready pod \
    --selector=group=org.example.project \
    --all-namespaces \
    --timeout=2m > /dev/null 2>&1
then
    info "All pods in all users are Ready"
else
    die "Somo pods may be unhealthy, please check visually from the console."
fi

info "Deployment on all users done."
info "Mocks deleted."
info "All done."