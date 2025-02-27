#!/bin/bash
set -euo pipefail

DOCKER_USER="${DOCKER_USER:-lhotari}"

VERSION_TAG=${VERSION_TAG:-"v1"}

TAGS=(
  "${DOCKER_USER}/pulsar-release-validation-base:${VERSION_TAG}"
  "${DOCKER_USER}/pulsar-release-validation-base:latest"
)
PLATFORMS="linux/amd64,linux/arm64"

# Build and push the multi-platform image
docker buildx build \
  --platform ${PLATFORMS} \
  $(printf -- '--tag %s ' "${TAGS[@]}") \
  --push \
  .