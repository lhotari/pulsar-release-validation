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

# Docker image to use
$imageName = $env:PULSAR_RELEASE_VALIDATION_IMAGE ?? "lhotari/pulsar-release-validation:1"
Write-Host "Using image: $imageName"
Write-Host "Pulling the image will take a while since it includes the maven dependencies required to build Pulsar..."
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

try {
    # Add more verbose output
    Write-Host "Running validation script in container..."
    
    # Run with error checking and more verbose output
    $dockerCmd = @'
set -e;
scriptUrl="$1";
shift
echo "Downloading validation script $scriptUrl...";
mkdir -p /pulsar_validation;
curl -s -f -o /pulsar_validation/validate_pulsar_release.sh "$scriptUrl" || { echo "Failed to download script"; exit 1; };
echo "Making script executable...";
chmod +x /pulsar_validation/validate_pulsar_release.sh;
echo "Running validation script with arguments: $@";
source "${SDKMAN_DIR}/bin/sdkman-init.sh";
# use java 17 for 3.0.x releases
if [[ "$@" == *"3.0."* ]]; then
    echo "Using java 17";
    sdk u java 17;
fi
# Pulsar build requires a lot of memory due to unefficient NAR file creation https://github.com/apache/nifi-maven/pull/35#issuecomment-2116764510
export MAVEN_OPTS="-Xss1500k -XX:MaxRAMPercentage=70.0 -XX:+UnlockDiagnosticVMOptions -XX:GCLockerRetryAllocationCount=100"
/pulsar_validation/validate_pulsar_release.sh "$@"
'@
    # Convert Windows line endings (CRLF) to Unix line endings (LF)
    $dockerCmd = $dockerCmd -replace "`r`n", "`n"
    
    docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock `
      --rm --network $DockerNetwork -e DOCKER_NETWORK=$DockerNetwork $imageName `
      bash -c $dockerCmd bash "$scriptUrl" @args
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker container exited with error code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
finally {
    # Clean up resources
    if ($DockerNetwork) {
        docker network rm $DockerNetwork | Out-Null
        Write-Host "Deleted $DockerNetwork"
    }
}