#!/bin/bash

# Exit on error
set -e

# Configuration
DEPLOYMENT_NAME="landingZoneDeployment"
LOCATION="uksouth"  # Default location for deployment scope
BICEP_FILE="main.bicep"
PARAM_FILE="main.parameters.json"

# Optional: allow overriding location
if [ "$1" != "" ]; then
  LOCATION=$1
fi

echo "------------------------------------------------------------"
echo "Starting Bicep deployment: $DEPLOYMENT_NAME"
echo "Location: $LOCATION"
echo "Template: $BICEP_FILE"
echo "Parameters: $PARAM_FILE"
echo "------------------------------------------------------------"

# Validate template
echo "🔍 Validating Bicep file..."
az deployment sub validate \
  --location "$LOCATION" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$BICEP_FILE" \
  --parameters @"$PARAM_FILE"

echo "✅ Validation succeeded."

# Deploy template
echo "🚀 Deploying Bicep template..."
az deployment sub create \
  --location "$LOCATION" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$BICEP_FILE" \
  --parameters @"$PARAM_FILE"

echo "🎉 Deployment complete!"
