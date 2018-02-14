#!/bin/sh

# Variables
MONGOD_STATEFULSET="mongod-ss"
MONGOD_NAMESPACE="ns-mongo"

# Namespace
kubectl apply -f mongodb-namespace.yaml

# Create keyfile for the MongoD cluster as a Kubernetes shared secret
TMPFILE=$(mktemp)
/usr/bin/openssl rand -base64 741 > $TMPFILE
kubectl create secret generic shared-bootstrap-data -n ${MONGOD_NAMESPACE} --from-file=internal-auth-mongodb-keyfile=$TMPFILE
rm $TMPFILE

# Create mongodb service with mongod stateful-set
kubectl apply -f mongodb-service.yaml
echo

# Wait until the final (3rd) mongod has started properly
echo "Waiting for the 3 containers to come up (`date`)..."
echo " (IGNORE any reported not found & connection errors)"
sleep 30
echo -n "  "
until kubectl --v=0 exec ${MONGOD_STATEFULSET}-2 -n ${MONGOD_NAMESPACE} -c mongod-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
echo "...mongod containers are now running (`date`)"
echo

# Deploy Mongo Client for test
kubectl run mongo-client -n $MONGOD_NAMESPACE --image=mongoclient/mongoclient

# Print current deployment state
kubectl get pv
echo
kubectl get svc,sts,pvc -n ${MONGOD_NAMESPACE}

