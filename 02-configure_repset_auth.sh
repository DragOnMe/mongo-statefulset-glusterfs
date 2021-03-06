#!/bin/bash
##
# Script to connect to the first Mongod instance running in a container of the
# Kubernetes StatefulSet, via the Mongo Shell, to initalise a MongoDB Replica
# Set and create a MongoDB admin user.
#
# IMPORTANT: Only run this once all 3 StatefulSet mongod pods are shown with
# status running (to see pod status run: $ kubectl get all -n $MONGOD_NAMESPACE)
##

# Variables
MONGOD_STATEFULSET="mongod-ss"
MONGOD_NAMESPACE="ns-mongo"

# Check for password argument
if [[ $# -eq 0 ]] ; then
    echo 'You must provide one argument for the password of the "main_admin" user to be created'
    echo '  Usage:  configure_repset_auth.sh PaSs123'
    echo
    exit 1
fi

# Initiate MongoDB Replica Set configuration
echo "Configuring the MongoDB Replica Set"
kubectl exec $MONGOD_STATEFULSET-0 -n $MONGOD_NAMESPACE -c mongod-container -- mongo --eval 'rs.initiate({_id: "MainRepSet", version: 1, members: [ {_id: 0, host: "'"${MONGOD_STATEFULSET}"'-0.mongodb-hs.'"${MONGOD_NAMESPACE}"'.svc.cluster.local:27017"}, {_id: 1, host: "'"${MONGOD_STATEFULSET}"'-1.mongodb-hs.'"${MONGOD_NAMESPACE}"'.svc.cluster.local:27017"}, {_id: 2, host: "'"${MONGOD_STATEFULSET}"'-2.mongodb-hs.'"${MONGOD_NAMESPACE}"'.svc.cluster.local:27017"} ]});'
echo

# Wait for the MongoDB Replica Set to have a primary ready
echo "Waiting for the MongoDB Replica Set to initialise..."
kubectl exec $MONGOD_STATEFULSET-0 -n $MONGOD_NAMESPACE -c mongod-container -- mongo --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
#sleep 2 # Just a little more sleep to ensure everything is ready!
sleep 20 # More sleep to ensure everything is ready! (3.6.0 workaround for https://jira.mongodb.org/browse/SERVER-31916 )
echo "...initialisation of MongoDB Replica Set completed"
echo

# Create the admin user (this will automatically disable the localhost exception)
echo "Creating user: 'main_admin'"
kubectl exec ${MONGOD_STATEFULSET}-0 -n ${MONGOD_NAMESPACE} -c mongod-container -- mongo --eval 'db.getSiblingDB("admin").createUser({user:"main_admin",pwd:"'"${1}"'",roles:[{role:"root",db:"admin"}]});'
echo

