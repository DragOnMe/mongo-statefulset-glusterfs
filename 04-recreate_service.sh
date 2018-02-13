#!/bin/sh
##
# Script to just deploy the MongoDB Service & StatefulSet back onto the exising Kubernetes cluster.
##

# Variables
MONGOD_STATEFULSET="mongod-ss"
MONGOD_NAMESPACE="ns-mongo"

# Show persistent volume claims are still reserved even though mongod stateful-set not deployed
kubectl get pv

# Deploy just the mongodb service with mongod stateful-set only
kubectl apply -f mongodb-service.yaml
sleep 5

# Print current deployment state (unlikely to be finished yet)
kubectl get svc,sts,pods -n ${MONGOD_NAMESPACE}
kubectl get pv
echo
echo "Keep running the following command until all 'mongod-ss-n' pods are shown as running:  kubectl get svc,sts,pods -n ${MONGOD_NAMESPACE}"
echo

