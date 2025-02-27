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

# default lhotari/pulsar-release-validation version for images and scripts
# this is bumped when there's a backwards incompatible change in the script or images
scriptVersion=${PULSAR_RELEASE_VALIDATION_SCRIPT_VERSION:-"v1"}

# Docker image with maven repository cache to use
imageName=${PULSAR_RELEASE_VALIDATION_IMAGE:-"lhotari/pulsar-release-validation:$scriptVersion"}
# Docker image without maven repository cache to use
baseImageName=${PULSAR_RELEASE_VALIDATION_BASE_IMAGE:-"lhotari/pulsar-release-validation-base:$scriptVersion"}
# Docker volume to use for caching maven dependencies, set to "none" to disable caching
m2CacheVolumeName=${PULSAR_RELEASE_VALIDATION_M2_CACHE_VOLUME:-"pulsar_release_validation_m2_cache"}

if [[ -n "$baseImageName" && -n "$m2CacheVolumeName" && "$m2CacheVolumeName" != "none" ]]; then
    echo "Using Maven repository cache volume: $m2CacheVolumeName"
    if [[ -z "$(docker volume ls -q -f name=$m2CacheVolumeName)" ]]; then
        echo "Volume $m2CacheVolumeName does not exist, creating it..."
        docker volume create $m2CacheVolumeName || { echo "Error: Failed to create volume $m2CacheVolumeName" >&2; exit 1; }
        echo "Pulling the image will take a while since it includes the majority of the maven dependencies required to build Pulsar..."
        docker pull $imageName
        # Docker will copy files from the image to the volume when the container is started and it already contains the files
        echo "Copying maven repository cache to volume $m2CacheVolumeName..."
        docker run --rm -v $m2CacheVolumeName:/root/.m2 $imageName /bin/bash -c "echo 'Files copied from $imageName to volume $m2CacheVolumeName'; rm -rf ~/.m2/repository/org/apache/pulsar; du -hs /root/.m2"
    fi
    imageName="$baseImageName"
    volumeMountOption="--volume $m2CacheVolumeName:/root/.m2"
    echo "Using image $imageName with mounted volume $m2CacheVolumeName"
else
    volumeMountOption=""
    echo "Maven repository cache volume is disabled. Using image $imageName"
fi

docker pull $imageName

# Url for the validate_pulsar_release.sh script
scriptUrl=${PULSAR_RELEASE_VALIDATION_SCRIPT:-"https://raw.githubusercontent.com/lhotari/pulsar-release-validation/refs/tags/$scriptVersion/scripts/validate_pulsar_release.sh"}
echo "Using validation script: $scriptUrl"

# Create unique docker network
DOCKER_NETWORK="pulsar_network_$$"
echo "Creating Docker network: $DOCKER_NETWORK"
docker network create $DOCKER_NETWORK || { echo "Error: Failed to create network $DOCKER_NETWORK" >&2; exit 1; }

cleanup_resources() {
    # Clean up the container
    if [[ -n "$containerName" ]]; then
        docker rm -f $containerName && echo "Deleted container $containerName"
    fi
    # Clean up the network
    if [[ -n "$DOCKER_NETWORK" ]]; then
        docker network rm $DOCKER_NETWORK && echo "Deleted $DOCKER_NETWORK"
    fi
}

# Set trap to clean up resources
trap cleanup_resources EXIT

# Generate a unique name for the Docker container
containerName="pulsar_validation_$(date +%s)"

# Add more verbose output
echo "Running validation script in container..."

# Run the container and capture its ID
docker run -it --name $containerName --privileged -v /var/run/docker.sock:/var/run/docker.sock \
  --rm $volumeMountOption --network $DOCKER_NETWORK -e DOCKER_NETWORK=$DOCKER_NETWORK $imageName \
  bash -c 'set -e
scriptUrl="$1"
shift
echo "Downloading validation script $scriptUrl..."
mkdir -p /pulsar_validation
curl -s -f -o /pulsar_validation/validate_pulsar_release.sh "$scriptUrl" || { echo "Failed to download script"; exit 1; }
echo "Making script executable..."
chmod +x /pulsar_validation/validate_pulsar_release.sh
echo "Running validation script with arguments: $@"
source "${SDKMAN_DIR}/bin/sdkman-init.sh"
pulsarVersion=$1
releaseCandidateNumber=$2
if [[ -n "$pulsarVersion" && -n "$releaseCandidateNumber" ]]; then
    echo "Running validation for Pulsar ${pulsarVersion}-candidate-${releaseCandidateNumber}"
    # use java 17 for 3.0.x releases
    if [[ "$pulsarVersion" == *"3.0."* ]]; then
        echo "Using Java 17"
        sdk u java 17
    fi
fi
# Pulsar build requires a lot of memory due to unefficient NAR file creation https://github.com/apache/nifi-maven/pull/35#issuecomment-2116764510
export MAVEN_OPTS="-Xss1500k -XX:MaxRAMPercentage=70.0 -XX:+UnlockDiagnosticVMOptions -XX:GCLockerRetryAllocationCount=100"
set +e
if [[ -n "$pulsarVersion" ]]; then
    # delete built Pulsar dependencies from the maven repository cache before running the validation script
    ls -G -d /root/.m2/repository/org/apache/pulsar/**/$pulsarVersion 2> /dev/null | xargs -r rm -rf
    du -hs /root/.m2
fi
/pulsar_validation/validate_pulsar_release.sh "$@"
retval=$?
if [[ -n "$pulsarVersion" ]]; then
    # delete built Pulsar dependencies from the maven repository cache
    echo "Deleting built Pulsar dependencies from the maven repository cache..."
    ls -G -d /root/.m2/repository/org/apache/pulsar/**/$pulsarVersion 2> /dev/null | xargs -r rm -rf
    du -hs /root/.m2
fi
exit $retval
' bash "$scriptUrl" "$@"

# Check exit code
if [ $? -ne 0 ]; then
    echo "Docker container exited with error" >&2
    exit 1
fi