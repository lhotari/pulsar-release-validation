# Apache Pulsar Release Candidate Validation Scripts {#overview}

Scripts to [validate Apache Pulsar release candidates](https://pulsar.apache.org/contribute/validate-release-candidate/) using Docker containers.
These scripts support both Unix-like systems (Bash) and Windows (PowerShell).

## Prerequisites {#prerequisites}

- Docker with docker-in-docker support for running the validation script that launches a Cassandra container inside a container
  - This is required for the validation script to work
  - You can test docker-in-docker support with this command:
    - `docker run --privileged -v /var/run/docker.sock:/var/run/docker.sock --rm -it lhotari/pulsar-release-validation:1 docker ps`
- Bash (for Unix-like systems) or PowerShell 7+ (for Windows)
- Fast internet connection for downloading the validation docker image and Pulsar release
  - The [validation docker image (≈2.5GB)](https://hub.docker.com/r/lhotari/pulsar-release-validation/tags) includes a snapshot of the majority of the maven dependencies required to build Pulsar.
  - The Pulsar build will download the remaining dependencies (≈0.7GB) at build time.

## Usage {#usage}

### Clone or download the repository {#repo-setup}

```shell
git clone https://github.com/lhotari/pulsar-release-validation
cd pulsar-release-validation
```

or [download the repository as a zip file](https://github.com/lhotari/pulsar-release-validation/archive/refs/heads/master.zip) and extract it.

### Run the validation script in a Docker container {#docker-validation}

#### On Unix-like systems (Linux, macOS) {#unix-validation}

```shell
./scripts/validate_pulsar_release_in_docker.sh [release-version] [candidate-number] | tee [log-file-name]
```

Examples:

```shell
# Validate release candidate 1 of version 3.0.10
./scripts/validate_pulsar_release_in_docker.sh 3.0.10 1 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 3.3.5
./scripts/validate_pulsar_release_in_docker.sh 3.3.5 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 4.0.3
./scripts/validate_pulsar_release_in_docker.sh 4.0.3 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log
```

#### On Windows (PowerShell) {#windows-validation}

```powershell
.\scripts\validate_pulsar_release_in_docker.ps1 [release-version] [candidate-number] | Tee-Object -FilePath [log-file-name]
```

Examples:

```powershell
# Validate release candidate 1 of version 3.0.10
.\scripts\validate_pulsar_release_in_docker.ps1 3.0.10 1 | Tee-Object -FilePath "validate_pulsar_release_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Validate release candidate 2 of version 3.3.5
.\scripts\validate_pulsar_release_in_docker.ps1 3.3.5 2 | Tee-Object -FilePath "validate_pulsar_release_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Validate release candidate 2 of version 4.0.3
.\scripts\validate_pulsar_release_in_docker.ps1 4.0.3 2 | Tee-Object -FilePath "validate_pulsar_release_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
```

### Maven Repository Cache {#maven-cache}

The validation script will use a persistent Docker volume to hold a Maven repository cache to speed up the build process of subsequent release candidate validations.
The cache volume is named `pulsar_release_validation_m2_cache`. It is created automatically when the first release candidate validation is run.
The volume's contents are primed with the maven dependencies included in the validation docker image. However, since it doesn't include all dependencies, the cache volume solution effectively prevents the "downloading the internet" problem when validating release candidates.

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

## Alternative Ways to Run the Validation Script {#alternative-validation}

### Run the validation script directly {#direct-validation}

One benefit of running the script directly is that if validation fails, you can retry without needing to re-download and rebuild the Pulsar release.

```shell
./scripts/validate_pulsar_release.sh [release-version] [candidate-number] | tee [log-file-name]
```

Examples:

```shell
# Validate release candidate 1 of version 3.0.10
./scripts/validate_pulsar_release.sh 3.0.10 1 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 3.3.5
./scripts/validate_pulsar_release.sh 3.3.5 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log

# Validate release candidate 2 of version 4.0.3
./scripts/validate_pulsar_release.sh 4.0.3 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log
```

## Cloud VM Instructions {#cloud-vm}

Running the validation in a cloud VM can be an efficient approach, especially for users with limited local resources or bandwidth.

### General Cloud VM Requirements {#vm-requirements}

Debian or Ubuntu based cloud VMs are available from all major cloud providers (AWS, Azure, GCP, etc.).

Pick a VM with at least:

- 8GB of RAM
- 4 CPU cores / 8 virtual CPUs
- 30GB of disk space (choose larger size for better performance)

The instructions below provide specifics for GCP, but similar approaches can be used on AWS and Azure with their respective CLI tools and VM offerings.

### Creating a VM in GCP {#gcp-vm-creation}

On GCP, `e2-highcpu-8` with 200GB of pd-ssd disk space is a good choice for running the validation script (about $0.24 hourly rate).
The 200GB disk space is recommended due to better disk I/O performance of larger disks.

#### Setting up GCP CLI {#gcp-cli-setup}

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

#### Creating a new VM {#new-vm-creation}

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

### VM Setup and Configuration {#vm-setup}

#### Installing Docker & tooling {#docker-install}

This configures the VM optimized for running Java applications, docker containers, and also enables profiling with async-profiler.

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

#### Reconnect and Run the Validation {#reconnect-validation}

After setting up the VM:

1. Reconnect to the VM:

   ```shell
   gcloud compute ssh pulsar-release-validation
   ```

2. Start a tmux session (allows reconnecting if connection drops):

   ```shell
   tmux
   ```
   
   If you are new to tmux, you can read [this article](https://www.redhat.com/en/blog/introduction-tmux-linux) for a quick start. For the key bindings, this [cheat sheet](https://tmuxcheatsheet.com/) is useful.
   
   If the connection is lost, you can reconnect to the tmux session with:

   ```shell
   tmux attach
   ```

3. Clone or update the repository and run validation:

   ```shell
   # Clone the repository if it doesn't exist, otherwise pull the latest changes
   [ ! -d pulsar-release-validation ] && git clone https://github.com/lhotari/pulsar-release-validation && cd pulsar-release-validation || cd pulsar-release-validation && git pull origin master
   # Run the validation script
   ./scripts/validate_pulsar_release_in_docker.sh 4.0.3 2 | tee validate_pulsar_release_`date +%Y-%m-%d_%H-%M-%S`.log
   ```

### GCP VM Disk Snapshot Management {#snapshot-management}

#### Creating a Disk Snapshot on GCP {#create-snapshot}

After validating a release, you can create a snapshot of the VM's disk to retain the configuration and Maven cache:

```shell
# First, lookup the boot disk name for the VM
BOOT_DISK_NAME=$(gcloud compute instances describe pulsar-release-validation --format="value(disks[0].source.basename())")
echo "Boot disk name: $BOOT_DISK_NAME"

# Create a snapshot of the VM's disk
gcloud compute disks snapshot $BOOT_DISK_NAME \
  --snapshot-names=pulsar-validation-snapshot \
  --description="Snapshot of Pulsar Release Validation VM with Maven cache"
```

#### Deleting the VM After Creating a Snapshot {#delete-vm}

Once you've created a snapshot, you can delete the VM to avoid ongoing charges:

```shell
gcloud compute instances delete pulsar-release-validation
```

#### Creating a New VM from a Snapshot {#vm-from-snapshot}

When you need to validate a new release, you can create a VM from your snapshot:

```shell
# First, create a disk from the snapshot
gcloud compute disks create pulsar-release-validation \
  --source-snapshot=pulsar-validation-snapshot \
  --size=200GB \
  --type=pd-ssd

# Then, create a VM using this disk
gcloud compute instances create pulsar-release-validation \
  --machine-type=e2-highcpu-8 \
  --disk=name=pulsar-release-validation,boot=yes
```

Now you can directly continue from the "Reconnect and Run the Validation" step.

### GCP Cost Considerations {#cost-considerations}

- **VM Costs**: An `e2-highcpu-8` VM costs approximately $145 per month ($0.21 per hour) when running.
- **Disk Cost**: The 200GB pd-ssd disk costs about $34 per month, whether the VM is running or stopped.
- **Disk Snapshot**: Keeping a disk snapshot costs less than $1/month for a 200GB snapshot.
- **Approach Comparison**:
  - **Stopped VM**: This will cost about $34 per month for the disk.
  - **Without Snapshot**: Each time you need to validate a release, you create a new VM and go through the entire setup process, including downloading and configuring all dependencies.
  - **With Snapshot**: You pay a small monthly fee (<$1) to store the snapshot but save significant time and bandwidth when validating new releases, as the VM will already have Docker installed, system tuned, and Maven dependencies cached.

This snapshot approach is particularly beneficial for frequent release validation or for users with limited bandwidth, as it eliminates the need to repeatedly download large Maven dependencies.