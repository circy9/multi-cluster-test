#!/bin/bash
# Create or delete a cluster.

# Print command
set -x

# SUBSCRIPTION_ID=${1:"2b03bfb8-e885-4566-a62a-909a11d71692"}
SUBSCRIPTION_ID=${1:"6ba5b177-6a65-4f5a-b1b9-f9c5b23bc49d"}
NAME_PREFIX=${2:-liqian}
LOCATION=${3:-westus2}
RESOURCE_GROUP="${NAME_PREFIX}-rg"

AZURE_CLIENT_SECRET=
AZURE_TENANT_ID=
AZURE_CLIENT_ID=

#####################################
# Create resource group
#####################################
echo "Creating resource group ${RESOURCE_GROUP}"
az group create \
--subscription "${SUBSCRIPTION_ID}" \
--name "${RESOURCE_GROUP}" \
--location "${LOCATION}" \
-o none
echo "Created resource group ${RESOURCE_GROUP}"

#####################################
# Create vnet
#####################################
VNET="${NAME_PREFIX}-vnet"
VNET_ADDRESS_PREFIX="10.0.0.0/16"
echo "Creating vnet ${VNET} with address prefix ${VNET_ADDRESS_PREFIX}"
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VNET}" \
  --address-prefix "${VNET_ADDRESS_PREFIX}"
echo "Created vnet ${VNET}"

#####################################
# Create cluster 1 in subnet 1
#####################################
SUBNET1="${NAME_PREFIX}-subnet1"
SUBNET_ADDRESS_PREFIXES1="10.0.1.0/24"
echo "Creating subnet ${SUBNET1} with address prefixes ${SUBNET_ADDRESS_PREFIXES1}"
SUBNET_ID1=$(az network vnet subnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${VNET}" \
  --name "${SUBNET1}" \
  --address-prefixes "${SUBNET_ADDRESS_PREFIXES1}" \
  --query id \
  -o tsv)
echo "Created subnet ${SUBNET1} with id ${SUBNET_ID1}"

CLUSTER1="${NAME_PREFIX}-cluster1"
DNS_SERVICE_IP1="10.0.10.10"
SERVICE_CIDR1="10.0.10.0/24"
az aks create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${CLUSTER1} \
    --no-ssh-key \
    --enable-managed-identity \
    --network-plugin azure \
    --vnet-subnet-id ${SUBNET_ID1} \
    --dns-service-ip ${DNS_SERVICE_IP1} \
    --service-cidr ${SERVICE_CIDR1} \
    --node-count 1

az aks get-credentials -n "${CLUSTER1}" -g "${RESOURCE_GROUP}"

#####################################
# Create cluster 2 in subnet 2
#####################################
SUBNET2="${NAME_PREFIX}-subnet2"
SUBNET_ADDRESS_PREFIXES2="10.0.2.0/24"
echo "Creating subnet ${SUBNET2} with address prefixes ${SUBNET_ADDRESS_PREFIXES2}"
SUBNET_ID2=$(az network vnet subnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${VNET}" \
  --name "${SUBNET2}" \
  --address-prefixes "${SUBNET_ADDRESS_PREFIXES2}" \
  --query id \
  -o tsv)
echo "Created subnet ${SUBNET2} with id ${SUBNET_ID2}"

CLUSTER2="${NAME_PREFIX}-cluster2"
DNS_SERVICE_IP2="10.0.20.10"
SERVICE_CIDR2="10.0.20.0/24"
az aks create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${CLUSTER2} \
    --no-ssh-key \
    --enable-managed-identity \
    --network-plugin azure \
    --vnet-subnet-id ${SUBNET_ID2} \
    --dns-service-ip ${DNS_SERVICE_IP2} \
    --service-cidr ${SERVICE_CIDR2} \
    --node-count 1

az aks get-credentials -n "${CLUSTER2}" -g "${RESOURCE_GROUP}"