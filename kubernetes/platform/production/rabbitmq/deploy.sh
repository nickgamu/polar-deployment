#!/bin/bash

set -euo pipefail

echo "\nš° RabbitMQ deployment started."

echo "\nš¦ Installing RabbitMQ Cluster Kubernetes Operator..."

kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/download/v1.13.1/cluster-operator.yml"

echo "\nā Waiting for RabbitMQ Operator to be deployed..."

while [ $(kubectl get pod -l app.kubernetes.io/name=rabbitmq-cluster-operator -n rabbitmq-system | wc -l) -eq 0 ] ; do
  sleep 15
done

echo "\nā Waiting for RabbitMQ Operator to be ready..."

kubectl wait \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=rabbitmq-cluster-operator \
  --timeout=300s \
  --namespace=rabbitmq-system

echo "\n ā The RabbitMQ Cluster Kubernetes Operator has been successfully installed."

echo "\n-----------------------------------------------------"

echo "\nš¦ Deploying RabbitMQ cluster..."

kubectl apply -f resources/cluster.yml

echo "\nā Waiting for RabbitMQ cluster to be deployed..."

while [ $(kubectl get pod -l app.kubernetes.io/name=polar-rabbitmq -n rabbitmq-system | wc -l) -eq 0 ] ; do
  sleep 15 
done

echo "\nā Waiting for RabbitMQ cluster to be ready..."

kubectl wait \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=polar-rabbitmq \
  --timeout=600s \
  --namespace=rabbitmq-system

echo "\nā The RabbitMQ cluster has been successfully deployed."

echo "\n-----------------------------------------------------"

export RABBITMQ_USERNAME=$(kubectl get secret polar-rabbitmq-default-user -o jsonpath='{.data.username}' -n=rabbitmq-system | base64 --decode)
export RABBITMQ_PASSWORD=$(kubectl get secret polar-rabbitmq-default-user -o jsonpath='{.data.password}' -n=rabbitmq-system | base64 --decode)

echo "Username: $RABBITMQ_USERNAME"
echo "Password: $RABBITMQ_PASSWORD"


echo "\nš Generating Secret with RabbitMQ credentials."

kubectl delete secret polar-rabbitmq-credentials || true

kubectl create secret generic polar-rabbitmq-credentials \
    --from-literal=spring.rabbitmq.host=polar-rabbitmq.rabbitmq-system.svc.cluster.local \
    --from-literal=spring.rabbitmq.port=5672 \
    --from-literal=spring.rabbitmq.username="$RABBITMQ_USERNAME" \
    --from-literal=spring.rabbitmq.password="$RABBITMQ_PASSWORD"

unset RABBITMQ_USERNAME
unset RABBITMQ_PASSWORD

echo "\nš Secret 'polar-rabbitmq-credentials' has been created for Spring Boot applications to interact with RabbitMQ."

echo "\nš° RabbitMQ deployment completed.\n"