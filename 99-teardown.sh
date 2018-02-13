#!/bin/sh
##
# Script to remove/undepoy all project resources from GKE & GCE.
##

# Delete mongod stateful set + mongodb service + secrets + host vm configuer daemonset
kubectl delete sts -n ns-mongo mongod-ss
kubectl delete svc -n ns-mongo mongodb-hs
kubectl delete secret -n ns-mongo shared-bootstrap-data
sleep 3

# Delete persistent volume claims
kubectl delete pvc -n ns-mongo -l role=mongo

# Delete namespace
kubectl delete ns ns-mongo
