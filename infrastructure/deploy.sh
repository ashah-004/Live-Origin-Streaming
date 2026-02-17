#!/bin/bash
set -e

echo "starting deployment..."

echo "creating namespaces..."
kubectl apply -f namespace.yaml

echo "deploying redis..."
helm upgrade --install redis-store bitnami/redis \
    --namespace redis-ns \
    -f redis.yaml

echo "deploying cassandra..."
helm upgrade --install cassandra-db bitnami/cassandra \
    --namespace cassandra-ns \
    -f cassandra.yaml

kubectl rollout status statefulset/cassandra-db -n cassandra-ns --timeout=300s

echo "databse schema..."
kubectl cp schema.cql cassandra-ns/cassandra-db-0:/tmp/schema.cql
kubectl exec -it cassandra-db-0 -n cassandra-ns -- cqlsh -u cassandra -p netflix -f /tmp/schema.cql

echo "deployment complete, backend ready..."