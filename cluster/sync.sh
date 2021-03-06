#!/bin/bash -e

registry_port=$(./cluster/cli.sh ports registry | tr -d '\r')
registry=localhost:$registry_port

./cluster/clean.sh

IMAGE_REGISTRY=$registry make docker-build docker-push

for i in $(seq 1 ${CLUSTER_NUM_NODES}); do
    ./cluster/cli.sh ssh "node$(printf "%02d" ${i})" 'sudo docker pull registry:5000/cluster-network-addons-operator'
    # Temporary until image is updated with provisioner that sets this field
    # This field is required by buildah tool
    ./cluster/cli.sh ssh "node$(printf "%02d" ${i})" 'sudo sysctl -w user.max_user_namespaces=1024'
done

./cluster/kubectl.sh create -f deploy/cluster-network-addons-operator_00_namespace.yaml
./cluster/kubectl.sh create -f deploy/cluster-network-addons-operator_01_crd.yaml
./cluster/kubectl.sh create -f deploy/cluster-network-addons-operator_02_rbac.yaml
sed 's#quay.io/kubevirt/cluster-network-addons-operator#registry:5000/cluster-network-addons-operator#' deploy/cluster-network-addons-operator_03_deployment.yaml | ./cluster/kubectl.sh create -f -
