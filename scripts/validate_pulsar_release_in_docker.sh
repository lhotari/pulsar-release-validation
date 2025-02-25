#!/bin/bash
#
# This script validates a Pulsar release in a Docker container.
# Usage:
# ./validate_pulsar_release_in_docker.sh [release-version] [candidate-number]
#
# Prerequisites:
# - Docker with docker-in-docker support

# Enable strict mode
set -e

# Docker image to use
imageName=${PULSAR_RELEASE_VALIDATION_IMAGE:-"lhotari/pulsar-release-validation:1"}
echo "Using image: $imageName"
docker pull $imageName

# Url for the validate_pulsar_release.sh script
scriptUrl=${PULSAR_RELEASE_VALIDATION_SCRIPT:-"https://raw.githubusercontent.com/lhotari/pulsar-release-validation/refs/heads/master/scripts/validate_pulsar_release.sh"}
echo "Using validation script: $scriptUrl"

# Create unique docker network
DOCKER_NETWORK="pulsar_network_$$"
echo "Creating Docker network: $DOCKER_NETWORK"
docker network create $DOCKER_NETWORK || { echo "Error: Failed to create network $DOCKER_NETWORK" >&2; exit 1; }

cleanup_resources() {
    if [[ -n "$DOCKER_NETWORK" ]]; then
        docker network rm $DOCKER_NETWORK && echo "Deleted $DOCKER_NETWORK"
    fi
}

# Set trap to clean up resources
trap cleanup_resources EXIT

# Add more verbose output
echo "Running validation script in container..."

# Run the Docker container
docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock \
  --rm --network $DOCKER_NETWORK -e DOCKER_NETWORK=$DOCKER_NETWORK $imageName \
  bash -c 'set -e;
scriptUrl="$1";
shift
echo "Downloading validation script $scriptUrl...";
mkdir -p /pulsar_validation;
curl -s -f -o /pulsar_validation/validate_pulsar_release.sh "$scriptUrl" || { echo "Failed to download script"; exit 1; };
echo "Making script executable...";
chmod +x /pulsar_validation/validate_pulsar_release.sh;
echo "Running validation script with arguments: $@";
source "${SDKMAN_DIR}/bin/sdkman-init.sh";
/pulsar_validation/validate_pulsar_release.sh "$@"' bash "$scriptUrl" "$@"

# Check exit code
if [ $? -ne 0 ]; then
    echo "Docker container exited with error" >&2
    exit 1
fi