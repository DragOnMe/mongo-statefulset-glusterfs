#!/bin/sh
##
# Script to remove/undepoy all project resources from K8s cluster
##

# Variables
MONGOD_STATEFULSET="mongod-ss"
MONGOD_NAMESPACE="ns-mongo"

# Delete mongod stateful set, mongodb service, secrets
kubectl delete sts -n ${MONGOD_NAMESPACE} ${MONGOD_STATEFULSET}
kubectl delete svc -n ${MONGOD_NAMESPACE} mongodb-hs
kubectl delete secret -n ${MONGOD_NAMESPACE} shared-bootstrap-data
sleep 3

# Delete persistent volume claims
kubectl delete pvc -n ${MONGOD_NAMESPACE} -l role=mongo

# Delete mongoclient pod & deployment
kubectl delete deployment mongo-client -n ${MONGOD_NAMESPACE}

# Delete namespace
kubectl delete ns ${MONGOD_NAMESPACE}
