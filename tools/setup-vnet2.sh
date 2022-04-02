#!/bin/bash
# Set up another cluster in vnet2 in the same region.

# Print command
set -x

NAME_PREFIX=${1:-liqian}
LOCATION=${2:-westus2}
RESOURCE_GROUP="${NAME_PREFIX}-rg"
# SUBSCRIPTION_ID="2b03bfb8-e885-4566-a62a-909a11d71692"
SUBSCRIPTION_ID="6ba5b177-6a65-4f5a-b1b9-f9c5b23bc49d"

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
# Create vnet 2
#####################################
VNET2="${NAME_PREFIX}-vnet2"
VNET_ADDRESS_PREFIX2="10.2.0.0/16"
echo "Creating vnet ${VNET2} with address prefix ${VNET_ADDRESS_PREFIX2}"
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VNET2}" \
  --address-prefix "${VNET_ADDRESS_PREFIX2}"
echo "Created vnet ${VNET2}"

#####################################
# Peer vnet 1 with vnet 2
#####################################
VNET1="${NAME_PREFIX}-vnet"

echo "Getting the id for ${VNET1}"
VNET1_ID=$(az network vnet show --resource-group ${RESOURCE_GROUP} --name ${VNET1} --query id --out tsv)

echo "Getting the id for ${VNET2}"
VNET2_ID=$(az network vnet show --resource-group ${RESOURCE_GROUP} --name ${VNET2} --query id --out tsv)

echo "Peering ${VNET1} to ${VNET2}"
PEER12_NAME="${VNET1}-${VNET2}-peer"
az network vnet peering create \
  --name ${PEER12_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --vnet-name ${VNET1} \
  --remote-vnet ${VNET2} \
  --allow-vnet-access

echo "Peering ${VNET2} to ${VNET1}"
PEER12_NAME="${VNET2}-${VNET1}-peer"
az network vnet peering create \
  --name ${PEER12_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --vnet-name ${VNET2} \
  --remote-vnet ${VNET1} \
  --allow-vnet-access

#####################################
# Create cluster 3 in subnet 3
#####################################
SUBNET="${NAME_PREFIX}-subnet3"
SUBNET_ADDRESS_PREFIXES="10.2.3.0/24"
echo "Creating subnet ${SUBNET3} with address prefixes ${SUBNET_ADDRESS_PREFIXES}"
SUBNET_ID=$(az network vnet subnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --vnet-name "${VNET2}" \
  --name "${SUBNET}" \
  --address-prefixes "${SUBNET_ADDRESS_PREFIXES}" \
  --query id \
  -o tsv)
echo "Created subnet ${SUBNET} with id ${SUBNET_ID}"

CLUSTER="${NAME_PREFIX}-cluster3"
DNS_SERVICE_IP="10.2.30.10"
SERVICE_CIDR="10.2.30.0/24"
az aks create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${CLUSTER} \
    --no-ssh-key \
    --enable-managed-identity \
    --network-plugin azure \
    --vnet-subnet-id ${SUBNET_ID} \
    --dns-service-ip ${DNS_SERVICE_IP} \
    --service-cidr ${SERVICE_CIDR} \
    --node-count 1

az aks get-credentials -n "${CLUSTER}" -g "${RESOURCE_GROUP}"
