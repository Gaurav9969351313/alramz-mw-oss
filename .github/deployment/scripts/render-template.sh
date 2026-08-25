#!/bin/bash

set -e

SERVICE="$1"
IMAGE="$2"

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

export SERVICE
export IMAGE
export CONTAINER_NAME="$SERVICE"

export CPU=$(yq '.container.cpu' "$CONFIG")
export MEMORY=$(yq '.container.memory' "$CONFIG")
export TARGET_PORT=$(yq '.container.targetPort' "$CONFIG")

export MIN_REPLICAS=$(yq '.scale.minReplicas' "$CONFIG")
export MAX_REPLICAS=$(yq '.scale.maxReplicas' "$CONFIG")

export INGRESS_EXTERNAL=$(yq '.ingress.external' "$CONFIG")

SPRING_PROFILE=$(yq '.environment.springProfile' "$CONFIG")
if [ -n "${SPRING_PROFILE_OVERRIDE:-}" ]; then
  SPRING_PROFILE="$SPRING_PROFILE_OVERRIDE"
fi
export SPRING_PROFILE
export JAVA_OPTS=$(yq '.environment.javaOpts' "$CONFIG")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="$SCRIPT_DIR/../templates/containerapp-template.yaml"

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "Error: Template file not found at $TEMPLATE_PATH"
  exit 1
fi

envsubst '${LOCATION} ${ACA_ENVIRONMENT_ID} ${MANAGED_IDENTITY} ${ACR_SERVER} ${SPRING_PROFILE} ${JAVA_OPTS} ${CONTAINER_NAME} ${IMAGE} ${INGRESS_EXTERNAL} ${CPU} ${MEMORY} ${TARGET_PORT} ${MIN_REPLICAS} ${MAX_REPLICAS} ${KEYVAULT_NAME}' < "$TEMPLATE_PATH" > containerapp.yaml
