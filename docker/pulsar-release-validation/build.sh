#!/bin/bash
set -euo pipefail

DOCKER_USER="${DOCKER_USER:-lhotari}"

VERSION_TAG=${VERSION_TAG:-"v1"}

TAGS=(
  "${DOCKER_USER}/pulsar-release-validation:${VERSION_TAG}"
  "${DOCKER_USER}/pulsar-release-validation:latest"
)
PLATFORMS="linux/amd64,linux/arm64"

# Build the m2-repo-cache-builder stage, caching the maven dependencies so that
# downloaded dependencies can be shared across platforms which are built in isolation.
docker buildx build \
  --platform ${PLATFORMS} \
  --no-cache \
  --progress=plain \
  --target m2-repo-cache-builder \
  --cache-from type=local,src=.buildcache \
  --cache-to type=local,dest=.buildcache \
  -t m2-repo-cache:latest \
  .

# Build and push the multi-platform image
docker buildx build \
  --platform ${PLATFORMS} \
  --no-cache \
  --progress=plain \
  --build-context m2-repo-cache=docker-image://m2-repo-cache:latest \
  $(printf -- '--tag %s ' "${TAGS[@]}") \
  --push \
  .