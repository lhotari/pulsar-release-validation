ARG VERSION_TAG=latest

FROM lhotari/pulsar-release-validation-base:${VERSION_TAG} AS m2-repo-cache-builder
RUN --mount=type=cache,target=/root/.m2,id=maven-cache /bin/bash <<'EOS'
source "${SDKMAN_DIR}/bin/sdkman-init.sh"
cd /tmp
git clone --depth=1 https://github.com/apache/pulsar
cd pulsar
echo "Downloading maven dependencies"
mvn -B -fn -ntp -T 1C dependency:go-offline
# Copy the cache contents to a location in the filesystem
mkdir -p /m2-cache
cp -r /root/.m2/* /m2-cache/
EOS

FROM lhotari/pulsar-release-validation-base:${VERSION_TAG}
COPY --from=m2-repo-cache /m2-cache /root/.m2