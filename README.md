# Apache Pulsar Release Candidate Validation Scripts

Scripts to [validate Apache Pulsar release candidates](https://pulsar.apache.org/contribute/validate-release-candidate/) using Docker containers.
Supports both Unix-like systems (Bash) and Windows (PowerShell).

## Prerequisites

- Docker with docker-in-docker support for running the validation script that launches a Cassandra container inside a container
  - This is required for the validation script to work
  - Testing of docker-in-docker support can be done with this command:
    - `docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it lhotari/pulsar-release-validation:1 docker ps`
- Bash (for Unix-like systems) or PowerShell 7+ (for Windows)
- Fast internet connection for downloading the validation docker image and Pulsar release.
  - The [validation docker image (≈2.5GB)](https://hub.docker.com/r/lhotari/pulsar-release-validation/tags) includes a snapshot of the maven dependencies required to build Pulsar.

## Usage

### Clone or download the repository

```shell
git clone https://github.com/lhotari/pulsar-release-validation
cd pulsar-release-validation
```

or [download the repository as a zip file](https://github.com/lhotari/pulsar-release-validation/archive/refs/heads/master.zip) and extract it.

### Run the validation script in a Docker container

#### On Unix-like systems (Linux, macOS)

```shell
./scripts/validate_pulsar_release_in_docker.sh [release-version] [candidate-number] | tee [log-file-name]
```

Examples

```shell
# Validate release candidate 1 of version 3.0.10
./scripts/validate_pulsar_release_in_docker.sh 3.0.10 1 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 3.3.5
./scripts/validate_pulsar_release_in_docker.sh 3.3.5 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 4.0.3
./scripts/validate_pulsar_release_in_docker.sh 4.0.3 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log
```

#### On Windows (PowerShell)

```powershell
.\scripts\validate_pulsar_release_in_docker.ps1 [release-version] [candidate-number] | Tee-Object -FilePath [log-file-name]
```

Examples

```powershell
# Validate release candidate 1 of version 3.0.10
.\scripts\validate_pulsar_release_in_docker.ps1 3.0.10 1 | Tee-Object -FilePath "validate_pulsar_release_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Validate release candidate 2 of version 3.3.5
.\scripts\validate_pulsar_release_in_docker.ps1 3.3.5 2 | Tee-Object -FilePath "validate_pulsar_release_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Validate release candidate 2 of version 4.0.3
.\scripts\validate_pulsar_release_in_docker.ps1 4.0.3 2 | Tee-Object -FilePath "validate_pulsar_release_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
```

### Maven Repository Cache

The validation script will use a persistent Docker volume to hold a Maven repository cache to speed up the build process of subsequent release candidate validations.
The cache volume is named `pulsar_release_validation_m2_cache`. It gets created automatically when the first release candidate validation is run.
The contents of the volume is primed with the maven dependencies included in the validation docker image, however since it doesn't include all the dependencies, the cache volume solution will effectively prevent the "downloading the internet" problem when validating release candidates.

If you'd like to delete the cache volume, you can do so with the following command:

```shell
docker volume rm pulsar_release_validation_m2_cache
```

To verify the disk usage of the cache volume, you can run the following command:

```shell
docker system df -v | grep pulsar_release_validation_m2_cache
```

To disable the Maven repository cache, set the following environment variable:

```shell
export PULSAR_RELEASE_VALIDATION_M2_CACHE_VOLUME=none
```

### Alternative Ways to Run the Validation Script

#### Run the validation script directly

One benefit of running the script directly is that if validation fails, you can retry without needing to re-download and rebuild the Pulsar release.

```shell
./scripts/validate_pulsar_release.sh [release-version] [candidate-number] | tee [log-file-name]
```

Examples

```shell
# Validate release candidate 1 of version 3.0.10
./scripts/validate_pulsar_release.sh 3.0.10 1 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 3.3.5
./scripts/validate_pulsar_release.sh 3.3.5 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 4.0.3
./scripts/validate_pulsar_release.sh 4.0.3 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log
```
