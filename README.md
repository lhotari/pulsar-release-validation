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

#### Run the validation script in a cloud VM in a Docker container

Debian or Ubuntu based cloud VMs are available from all major cloud providers.
Pick a VM with at least 8GB of RAM (for example e2-standard-2 on GCP).

The following steps show how to run the validation script in a cloud VM in a Docker container.

1. Create a Debian or Ubuntu based cloud VM.
2. Start the VM and SSH into it.
3. Install Docker and other tooling and logout.
4. SSH again
5. Start a tmux session so that you can reconnect later if the connection is lost.
6. Run the validation script.

##### Installing Docker & tooling*

```shell
sudo bash -c "apt-get update && apt-get install -y docker.io git tmux sysfsutils && adduser $USER docker"
cat <<EOF | sudo tee /etc/sysfs.d/transparent_hugepage.conf
# use "madvise" Linux Transparent HugePages (THP) setting
# https://www.kernel.org/doc/html/latest/admin-guide/mm/transhuge.html
# "madvise" is generally a better option than the default "always" setting
# Based on Azul instructions from https://docs.azul.com/prime/Enable-Huge-Pages#transparent-huge-pages-thp
kernel/mm/transparent_hugepage/enabled=madvise
kernel/mm/transparent_hugepage/shmem_enabled=madvise
kernel/mm/transparent_hugepage/defrag=defer+madvise
kernel/mm/transparent_hugepage/khugepaged/defrag=1
EOF
sudo systemctl enable sysfsutils.service
sudo systemctl restart sysfsutils.service
cat <<EOF | sudo tee /etc/sysctl.d/99-vm-tuning.conf
vm.max_map_count=262144
vm.swappiness=1
fs.aio-max-nr=1048576
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=1048576
EOF
sudo sysctl -p /etc/sysctl.d/99-vm-tuning.conf
sudo mkdir -p /etc/systemd/system.conf.d/
cat <<EOF | sudo tee /etc/systemd/system.conf.d/99-limits.conf
[Manager]
DefaultLimitNOFILE=1048576
EOF
sudo systemctl daemon-reload
cat <<EOF | sudo tee /etc/security/limits.d/99-limits.conf
*               soft    nofile          1048576
*               hard    nofile          1048576
EOF
sudo systemctl restart docker
exit
```

##### Start a tmux session

```shell
tmux
```

If the connection is lost, you can reconnect with the following command:

```shell
tmux attach
```

##### Install the validation script

```shell
git clone https://github.com/lhotari/pulsar-release-validation
cd pulsar-release-validation
```

##### Run the validation script

Run this in the `tmux` session so that you can reconnect later if the connection is lost.
GCP's web console will stall due to the amount of output from the validation script and you won't be able to see the output without tmux.

Examples

```shell
# Validate release candidate 1 of version 3.0.10
./scripts/validate_pulsar_release_in_docker.sh 3.0.10 1 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 3.3.5
./scripts/validate_pulsar_release_in_docker.sh 3.3.5 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 4.0.3
./scripts/validate_pulsar_release_in_docker.sh 4.0.3 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log
```