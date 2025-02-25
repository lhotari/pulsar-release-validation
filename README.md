# Apache Pulsar Release Candidate Validation Scripts

Scripts to [validate Apache Pulsar release candidates](https://pulsar.apache.org/contribute/validate-release-candidate/) using Docker containers.
Supports both Unix-like systems (Bash) and Windows (PowerShell).

## Prerequisites

- Docker with docker-in-docker support for running the validation script that launches a Cassandra container inside a container
  - This is required for the validation script to work
  - Testing of docker-in-docker support can be done with this command:
    - `docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it lhotari/pulsar-release-validation:1 docker ps`
- Bash (for Unix-like systems) or PowerShell 7+ (for Windows)

## Usage

### Clone the repository

```shell
git clone https://github.com/lhotari/pulsar-release-validation
cd pulsar-release-validation
```

### Run the validation script in a Docker container

On Unix-like systems (Linux, macOS):

```shell
./scripts/validate_pulsar_release_in_docker.sh [release-version] [candidate-number]
```

On Windows (PowerShell):

```shell
./scripts/validate_pulsar_release_in_docker.ps1 [release-version] [candidate-number]
```

### Examples

```shell
# Validate release candidate 1 of version 3.0.10
./scripts/validate_pulsar_release_in_docker.sh 3.0.10 1

# Validate release candidate 2 of version 3.3.5
./scripts/validate_pulsar_release_in_docker.sh 3.3.5 2

# Validate release candidate 2 of version 4.0.3
./scripts/validate_pulsar_release_in_docker.sh 4.0.3 2
```

## Alternative Ways to Run the Validation Script

### Run the validation script directly

One benefit of running the script directly is that if validation fails, you can retry without needing to re-download and rebuild the Pulsar release.

```shell
./scripts/validate_pulsar_release.sh [release-version] [candidate-number]
```
