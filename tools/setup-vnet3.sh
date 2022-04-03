#!/bin/bash
# Set up another cluster in vnet3 (10.3.0.0/16) in a region (eastus2) different from vnet1 (westus2).

# Print command
set -x

NAME_PREFIX=${1:-liqian}
LOCATION=${2:-eastus2}
RESOURCE_GROUP="${NAME_PREFIX}-rg"
RESOURCE_GROUP_W_LOCATION="${NAME_PREFIX}-${LOCATION}-rg"
# SUBSCRIPTION_ID="2b03bfb8-e885-4566-a62a-909a11d71692"
SUBSCRIPTION_ID="6ba5b177-6a65-4f5a-b1b9-f9c5b23bc49d"

#####################################
# Create resource group
#####################################
echo "Creating resource group ${RESOURCE_GROUP_W_LOCATION}"
az group create \
--subscription "${SUBSCRIPTION_ID}" \
--name "${RESOURCE_GROUP_W_LOCATION}" \
--location "${LOCATION}" \
-o none
echo "Created resource group ${RESOURCE_GROUP_W_LOCATION}"

#####################################
# Create vnet 3
#####################################
VNET3="${NAME_PREFIX}-vnet3"
VNET_ADDRESS_PREFIX3="10.3.0.0/16"
echo "Creating vnet ${VNET3} with address prefix ${VNET_ADDRESS_PREFIX3}"
az network vnet create \
  --resource-group "${RESOURCE_GROUP_W_LOCATION}" \
  --name "${VNET3}" \
  --address-prefix "${VNET_ADDRESS_PREFIX3}"
echo "Created vnet ${VNET3}"

#####################################
# Peer vnet 1 with vnet 3
#####################################
VNET1="${NAME_PREFIX}-vnet"

echo "Getting the id for ${VNET1}"
VNET1_ID=$(az network vnet show --resource-group ${RESOURCE_GROUP} --name ${VNET1} --query id --out tsv)

echo "Getting the id for ${VNET2}"
VNET3_ID=$(az network vnet show --resource-group ${RESOURCE_GROUP_W_LOCATION} --name ${VNET3} --query id --out tsv)

echo "Peering ${VNET1} to ${VNET3}"
PEER13_NAME="${VNET1}-${VNET3}-peer"
az network vnet peering create \
  --name ${PEER13_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --vnet-name ${VNET1} \
  --remote-vnet ${VNET3_ID} \
  --allow-vnet-access

echo "Peering ${VNET3} to ${VNET1}"
PEER13_NAME="${VNET3}-${VNET1}-peer"
az network vnet peering create \
  --name ${PEER13_NAME} \
  --resource-group ${RESOURCE_GROUP_W_LOCATION} \
  --vnet-name ${VNET3} \
  --remote-vnet ${VNET1_ID} \
  --allow-vnet-access

#####################################
# Create cluster 4 in subnet 4
#####################################
SUBNET="${NAME_PREFIX}-subnet4"
SUBNET_ADDRESS_PREFIXES="10.3.4.0/24"
echo "Creating subnet ${SUBNET4} with address prefixes ${SUBNET_ADDRESS_PREFIXES}"
SUBNET_ID=$(az network vnet subnet create \
  --resource-group "${RESOURCE_GROUP_W_LOCATION}" \
  --vnet-name "${VNET3}" \
  --name "${SUBNET}" \
  --address-prefixes "${SUBNET_ADDRESS_PREFIXES}" \
  --query id \
  -o tsv)
echo "Created subnet ${SUBNET} with id ${SUBNET_ID}"

CLUSTER="${NAME_PREFIX}-cluster4"
DNS_SERVICE_IP="10.3.40.10"
SERVICE_CIDR="10.3.40.0/24"
az aks create \
    --resource-group ${RESOURCE_GROUP_W_LOCATION} \
    --name ${CLUSTER} \
    --no-ssh-key \
    --enable-managed-identity \
    --network-plugin azure \
    --vnet-subnet-id ${SUBNET_ID} \
    --dns-service-ip ${DNS_SERVICE_IP} \
    --service-cidr ${SERVICE_CIDR} \
    --node-count 1

az aks get-credentials -n "${CLUSTER}" -g "${RESOURCE_GROUP_W_LOCATION}"
