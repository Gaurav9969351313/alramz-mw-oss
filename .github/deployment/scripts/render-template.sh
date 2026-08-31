#!/bin/bash

set -e

SERVICE="$1"
IMAGE="$2"

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

export SERVICE_NAME="$SERVICE"
export IMAGE

export CPU=$(yq '.container.cpu' "$CONFIG")
export MEMORY=$(yq '.container.memory' "$CONFIG")
export CPU_LIMIT=$(yq '.container.cpuLimit // .container.cpu' "$CONFIG")
export MEMORY_LIMIT=$(yq '.container.memoryLimit // .container.memory' "$CONFIG")
export TARGET_PORT=$(yq '.container.targetPort' "$CONFIG")

export MIN_REPLICAS=$(yq '.scale.minReplicas' "$CONFIG")
export MAX_REPLICAS=$(yq '.scale.maxReplicas' "$CONFIG")

SPRING_PROFILE=$(yq '.environment.springProfile' "$CONFIG")
if [ -n "${SPRING_PROFILE_OVERRIDE:-}" ]; then
  SPRING_PROFILE="$SPRING_PROFILE_OVERRIDE"
fi
export SPRING_PROFILE
export JAVA_OPTS=$(yq '.environment.javaOpts' "$CONFIG")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates/kubernetes"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: Kubernetes templates directory not found at $TEMPLATE_DIR"
  exit 1
fi

OUTPUT_FILE="k8s-manifests.yaml"
> "$OUTPUT_FILE"

for template in "$TEMPLATE_DIR"/*.yaml; do
  [ -f "$template" ] || continue
  envsubst < "$template" >> "$OUTPUT_FILE"
  echo "---" >> "$OUTPUT_FILE"
done

echo "Rendered Kubernetes manifests to $OUTPUT_FILE"
