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

Pick a VM with at least:

- 8GB of RAM
- 4 CPU cores / 8 virtual CPUs
- 30GB of disk space (choose larger size for better performance)

##### Creating a VM in GCP

On GCP, `e2-highcpu-8` with 200GB of pd-ssd disk space is a good choice for running the validation script. (about $0.24 hourly rate)
The 200GB disk space is used due to better disk I/O performance of larger disks.

You can create the VM in the GCP web console or using the command line.

For command line creation of the VM in GCP, you need to:

Login and Select Project:

```shell
gcloud auth login
gcloud projects list
gcloud config set project [project-id]
```

Set a default zone to avoid specifying it in every command:

```shell
gcloud config set compute/zone us-central1-c
```

Create VM:

```shell
gcloud compute instances create pulsar-release-validation \
  --machine-type=e2-highcpu-8 \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=200GB \
  --boot-disk-type=pd-ssd
```

Connect to VM via SSH:

```shell
gcloud compute ssh pulsar-release-validation
```

Stop VM (After Validation):

```shell
gcloud compute instances stop pulsar-release-validation
```

Delete VM (If No Longer Needed)

```shell
gcloud compute instances delete pulsar-release-validation
```

The benefit of keeping the VM stopped is that you can start it again later without needing to reconfigure the VM or re-download the Maven dependencies each time.
There will be a cost for keeping the VM stopped. You might want to create the VM with a smaller disk size to reduce the costs of keeping a stopped VM around.

##### Steps for setting up the VM and running the validation script

The following steps show how to run the validation script in a cloud VM in a Docker container.

1. Create a Debian or Ubuntu based cloud VM.
2. Start the VM and SSH into it.
3. Install Docker and other tooling and logout.
4. SSH again
5. Start a tmux session so that you can reconnect later if the connection is lost.
6. Run the validation script.

##### Installing Docker & tooling

This configures the VM optimized for running Java applications, docker containers and to also do profiling with async-profiler.

```shell
# Install Docker and other tooling
sudo bash -c "apt-get update && apt-get install -y docker.io git tig tmux sysfsutils htop curl zip unzip wget ca-certificates git gpg locales netcat-openbsd jq yq vim procps less netcat-openbsd dnsutils iputils-ping && adduser $USER docker"

# Tune Linux Transparent HugePages (THP) for Java processes
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

# Tune Linux kernel settings
cat <<EOF | sudo tee /etc/sysctl.d/99-vm-tuning.conf
# set swappiness to 1 to use swapping as a last resort
vm.swappiness=1
# set max_map_count to 262144 to allow large memory-mapped files
vm.max_map_count=262144
# set aio-max-nr to 1048576 to allow large asynchronous I/O, required by some docker container (not specific to Pulsar)
fs.aio-max-nr=1048576
# set inotify limits to allow large number of files to be watched
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=1048576
# allow async-profiler to profile non-root processes
# https://github.com/jvm-profiling-tools/async-profiler#basic-usage
# non-root process requires setting two runtime variables
kernel.perf_event_paranoid=1
kernel.kptr_restrict=0
# https://github.com/jvm-profiling-tools/async-profiler#restrictionslimitations
kernel.perf_event_max_stack=1024
# Profiler allocates 8kB perf_event buffer for each thread of the target process.
# Make sure value is large enough (more than 8 * threads)
kernel.perf_event_mlock_kb=2048
EOF
sudo sysctl -p /etc/sysctl.d/99-vm-tuning.conf

# Configure number of open files limits for systemd
sudo mkdir -p /etc/systemd/system.conf.d/
cat <<EOF | sudo tee /etc/systemd/system.conf.d/99-limits.conf
[Manager]
DefaultLimitNOFILE=1048576
EOF

# Configure number of open files limits for the default user
cat <<EOF | sudo tee /etc/security/limits.d/99-limits.conf
*               soft    nofile          1048576
*               hard    nofile          1048576
EOF

# Reload systemd to apply the changes to systemd
sudo systemctl daemon-reload

# Limit Docker logging to 10MB and 3 files
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker to apply the changes
sudo systemctl restart docker
exit
```

##### Reconnect to the VM

Reconnect to the VM so that the default user can use Docker without sudo.

##### Start a tmux session

If you are new to tmux, you can read [this article](https://www.redhat.com/en/blog/introduction-tmux-linux) for a quick start. For the key bindings, this [cheat sheet](https://tmuxcheatsheet.com/) is useful.

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

Examples

```shell
# Validate release candidate 1 of version 3.0.10
./scripts/validate_pulsar_release_in_docker.sh 3.0.10 1 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 3.3.5
./scripts/validate_pulsar_release_in_docker.sh 3.3.5 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 4.0.3
./scripts/validate_pulsar_release_in_docker.sh 4.0.3 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log
```