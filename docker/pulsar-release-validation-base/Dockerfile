FROM ubuntu:latest

ARG JAVA_17_VERSION=17.0.14-amzn
ARG JAVA_21_VERSION=21.0.6-amzn

ENV HOME=/root

RUN /bin/bash <<'EOS'
# Setup options for non-interactive apt-get
export DEBIAN_FRONTEND=noninteractive
export PERL_BADLANG=0

# Update package index
apt-get update
# Upgrade existing packages to the latest version
apt-get -y dist-upgrade

# apt packages to install
PACKAGES=$(cat <<'PKGLIST'
  # system utilities 
  locales ca-certificates apt-transport-https
  # docker
  docker.io
  # dev tools, etc.
  python3-minimal git tig vim tmux less ripgrep tree pv fzf
  # monitoring tools
  htop procps
  # networking tools
  curl wget netcat-openbsd dnsutils iputils-ping
  # compression & encryption utilities
  zip unzip gpg
  # json, yaml, xml utilities
  jq yq xmlstarlet
PKGLIST
)

# Install packages
apt-get -y install $(echo "$PACKAGES" | grep -v '^\s*#' | tr -s ' ' | tr '\n' ' ')

# Install uv, a fast modern package manager for Python for handling Python scripts that could be added later
curl -LsSf https://astral.sh/uv/install.sh | sh

# Configure locale
locale-gen en_US.UTF-8

# Cleanup
apt-get -y --purge autoremove
apt-get autoclean
apt-get clean
rm -rf /var/lib/apt/lists/*

EOS

# Install SDKMAN
ENV SDKMAN_DIR=/usr/local/sdkman
RUN /bin/bash <<EOS
set -eux
set -o pipefail
curl -s "https://get.sdkman.io" | bash
echo "sdkman_auto_answer=true" >> "\${SDKMAN_DIR}/etc/config"
EOS

# Install Java and Maven using SDKMAN
RUN /bin/bash <<EOS
source "\${SDKMAN_DIR}/bin/sdkman-init.sh"
sdk install java ${JAVA_17_VERSION}
cd "\${SDKMAN_DIR}/candidates/java"
ln -s ${JAVA_17_VERSION} 17
sdk install java ${JAVA_21_VERSION}
cd "\${SDKMAN_DIR}/candidates/java"
ln -s ${JAVA_21_VERSION} 21
sdk install maven
# Cleanup
sdk flush
EOS