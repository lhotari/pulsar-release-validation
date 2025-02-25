FROM ubuntu:latest
ARG JAVA_17_VERSION=17.0.14-amzn
ARG JAVA_21_VERSION=21.0.6-amzn
ARG DEBIAN_FRONTEND=noninteractive
ENV HOME=/root
RUN /bin/bash <<'EOS'
apt-get update
apt-get dist-upgrade -y
apt-get install -y curl zip unzip wget ca-certificates git gpg locales netcat-openbsd jq docker.io vim procps less netcat-openbsd dnsutils iputils-ping
locale-gen en_US.UTF-8
apt-get -y --purge autoremove
apt-get autoclean
apt-get clean
rm -rf /var/lib/apt/lists/*
EOS
ENV SDKMAN_DIR=/usr/local/sdkman
RUN /bin/bash <<EOS
set -eux
set -o pipefail
curl -s "https://get.sdkman.io" | bash
echo "sdkman_auto_answer=true" >> "\${SDKMAN_DIR}/etc/config"
EOS
RUN /bin/bash <<EOS
source "\${SDKMAN_DIR}/bin/sdkman-init.sh"
sdk install java ${JAVA_17_VERSION}
cd "\${SDKMAN_DIR}/candidates/java"
ln -s ${JAVA_17_VERSION} 17
sdk install java ${JAVA_21_VERSION}
cd "\${SDKMAN_DIR}/candidates/java"
ln -s ${JAVA_21_VERSION} 21
sdk install maven
sdk flush
EOS