#!/bin/bash

set -e

SERVICE=$1
IMAGE=$2

# Dynamically locate the service config file (supporting service.yaml, service.yml, and deployment.yaml)
CONFIG="services/${SERVICE}/service.yaml"
if [ ! -f "$CONFIG" ]; then
  CONFIG="services/${SERVICE}/service.yml"
fi
if [ ! -f "$CONFIG" ]; then
  CONFIG="services/${SERVICE}/deployment.yaml"
fi

if [ ! -f "$CONFIG" ]; then
  echo "Error: Configuration file not found for service ${SERVICE}"
  exit 1
fi

export IMAGE=$IMAGE
export CONTAINER_NAME=$SERVICE

export CPU=$(yq '.container.cpu' $CONFIG)
export MEMORY=$(yq '.container.memory' $CONFIG)
export TARGET_PORT=$(yq '.container.targetPort' $CONFIG)

export MIN_REPLICAS=$(yq '.scale.minReplicas' $CONFIG)
export MAX_REPLICAS=$(yq '.scale.maxReplicas' $CONFIG)

export INGRESS_EXTERNAL=$(yq '.ingress.external' $CONFIG)

export SPRING_PROFILE=$(yq '.environment.springProfile' $CONFIG)
export JAVA_OPTS=$(yq '.environment.javaOpts' $CONFIG)

#
# Global variables
#

export LOCATION=$LOCATION
export ACA_ENVIRONMENT_ID=$ACA_ENVIRONMENT_ID
export MANAGED_IDENTITY=$MANAGED_IDENTITY
export ACR_SERVER=$ACR_SERVER

# Resolve template path relative to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="$SCRIPT_DIR/../templates/containerapp-template.yaml"

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "Error: Template file not found at $TEMPLATE_PATH"
  exit 1
fi

envsubst < "$TEMPLATE_PATH" > containerapp.yaml