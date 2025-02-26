#!/usr/bin/env pwsh
#
# This script validates a Pulsar release in a Docker container.
# Usage:
# ./validate_pulsar_release_in_docker.ps1 [release-version] [candidate-number]
#
# Prerequisites:
# - Docker with docker-in-docker support

# Enable strict mode
$ErrorActionPreference = 'Stop'

# Docker image with maven repository cache to use
$imageName = $env:PULSAR_RELEASE_VALIDATION_IMAGE ?? "lhotari/pulsar-release-validation:1"
# Docker image without maven repository cache to use
$baseImageName = $env:PULSAR_RELEASE_VALIDATION_BASE_IMAGE ?? "lhotari/pulsar-release-validation-base:1"
# Docker volume to use for caching maven dependencies, set to "none" to disable caching
$m2CacheVolumeName = $env:PULSAR_RELEASE_VALIDATION_M2_CACHE_VOLUME ?? "pulsar_release_validation_m2_cache"

if ($baseImageName -and $m2CacheVolumeName -and $m2CacheVolumeName -ne "none") {
    Write-Host "Using Maven repository cache volume: $m2CacheVolumeName"
    $volumeExists = docker volume ls -q -f name=$m2CacheVolumeName
    if (-not $volumeExists) {
        Write-Host "Volume $m2CacheVolumeName does not exist, creating it..."
        docker volume create $m2CacheVolumeName
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error: Failed to create volume $m2CacheVolumeName"
            exit 1
        }
        Write-Host "Pulling the image will take a while since it includes the maven dependencies required to build Pulsar..."
        docker pull $imageName
        # Docker will copy files from the image to the volume when the container is started and it already contains the files
        Write-Host "Copying maven repository cache to volume $m2CacheVolumeName..."
        docker run --rm -v "${m2CacheVolumeName}:/root/.m2" $imageName /bin/bash -c "echo 'Files copied from $imageName to volume $m2CacheVolumeName'; rm -rf ~/.m2/repository/org/apache/pulsar; du -hs /root/.m2"
    }
    $imageName = $baseImageName
    $volumeMountOption = "--volume ${m2CacheVolumeName}:/root/.m2"
    Write-Host "Using image $imageName with mounted volume $m2CacheVolumeName"
} else {
    $volumeMountOption = ""
    Write-Host "Maven repository cache volume is disabled. Using image $imageName"
}

docker pull $imageName

# Url for the validate_pulsar_release.sh script
$scriptUrl = $env:PULSAR_RELEASE_VALIDATION_SCRIPT ?? "https://raw.githubusercontent.com/lhotari/pulsar-release-validation/refs/heads/master/scripts/validate_pulsar_release.sh"
Write-Host "Using validation script: $scriptUrl"

# Create unique docker network
$DockerNetwork = "pulsar_network_$(Get-Random)"
Write-Host "Creating Docker network: $DockerNetwork"
docker network create $DockerNetwork
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create network $DockerNetwork"
    exit 1
}

# Generate a unique name for the Docker container
$containerName = "pulsar_validation_$(Get-Random)"

try {
    # Add more verbose output
    Write-Host "Running validation script in container..."
    
    # Run with error checking and more verbose output
    $dockerCmd = @'
set -e
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
    ls -G -d /root/.m2/repository/org/apache/pulsar/**/$pulsarVersion 2> /dev/null | xargs -r rm -rf
    du -hs /root/.m2
fi
exit $retval
'@
    # Convert Windows line endings (CRLF) to Unix line endings (LF)
    $dockerCmd = $dockerCmd -replace "`r`n", "`n"
    
    # Handle volumeMountOption
    $volumeMountOptionArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($volumeMountOption)) {
        $volumeMountOptionArgs = $volumeMountOption.Split(" ")
    }
    
    # Run the container and capture its ID
    docker run --name $containerName --privileged -v /var/run/docker.sock:/var/run/docker.sock `
      $volumeMountOptionArgs --network $DockerNetwork -e DOCKER_NETWORK=$DockerNetwork $imageName `
      bash -c $dockerCmd bash "$scriptUrl" @args
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker container exited with error code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
finally {
    # Clean up resources
    # Clean up the container
    if ($containerName) {
        docker rm -f $containerName | Out-Null
        Write-Host "Deleted container $containerName"
    }
    # Clean up the network
    if ($DockerNetwork) {
        docker network rm $DockerNetwork | Out-Null
        Write-Host "Deleted $DockerNetwork"
    }
}