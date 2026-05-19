#!/bin/bash
# Deploy AI Foundry + AI Search with Private Endpoints
# This script prompts for all required parameters before deploying.

set -e

echo "=== AI Foundry + AI Search Private Network Deployment ==="
echo ""

# Prompt for parameters
read -p "Enter Azure subscription ID: " SUBSCRIPTION_ID
read -p "Enter resource group name: " RESOURCE_GROUP
read -p "Enter Azure region (e.g. australiaeast, eastus): " LOCATION
read -p "Enter resource name prefix (lowercase, no special chars): " PREFIX

echo ""
echo "--- Summary ---"
echo "Subscription:   $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location:       $LOCATION"
echo "Prefix:         $PREFIX"
echo "---------------"
echo ""
read -p "Proceed with deployment? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Deployment cancelled."
  exit 0
fi

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Create resource group if it doesn't exist
echo "Ensuring resource group '$RESOURCE_GROUP' exists in '$LOCATION'..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

# Deploy
echo "Starting Bicep deployment..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters prefix="$PREFIX" location="$LOCATION" \
  --output table

echo ""
echo "✅ Deployment complete!"
