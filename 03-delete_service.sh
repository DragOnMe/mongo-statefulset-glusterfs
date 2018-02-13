#!/bin/sh
##
# Script to just undeploy the MongoDB Service & StatefulSet but nothing else.
##

# Variables
MONGOD_STATEFULSET="mongod-ss"
MONGOD_NAMESPACE="ns-mongo"

# Just delete mongod stateful set + mongodb service onlys (keep rest of k8s environment in place)
kubectl delete sts -n ${MONGOD_NAMESPACE} ${MONGOD_STATEFULSET}
kubectl delete svc -n ${MONGOD_NAMESPACE} mongodb-hs

# Show persistent volume claims are still reserved even though mongod stateful-set has been undeployed
kubectl get pv

