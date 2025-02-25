#!/bin/bash
set -euo pipefail

DOCKER_USER="${DOCKER_USER:-lhotari}"

TAGS=(
  "${DOCKER_USER}/pulsar-release-validation:1"
  "${DOCKER_USER}/pulsar-release-validation:latest"
)
PLATFORMS="linux/amd64,linux/arm64"

# Build and push the multi-platform image
docker buildx build \
  --platform ${PLATFORMS} \
  $(printf -- '--tag %s ' "${TAGS[@]}") \
  --push \
  .