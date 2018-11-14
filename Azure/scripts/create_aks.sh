#!/bin/bash
# Load our environment settings
. ~/settings.sh

# Create our Kubernetes cluster
az aks create \
  --name $AZClusterName \
  --resource-group $AZResourceGroup \
  --location $AZRegion \
  --enable-addons monitoring \
  --generate-ssh-keys \
  --kubernetes-version 1.11.3 \
  --dns-name-prefix $AZDNSPrefix \
  --node-count $AZCluserNodes \
  --node-osdisk-size 30 \
  --node-vm-size $AZClusterServer

#  --service-principal X

