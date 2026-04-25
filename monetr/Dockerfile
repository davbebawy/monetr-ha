# Monetr binary version — keep in sync with `version` in config.yaml
ARG BUILD_VERSION=1.13.0
FROM ghcr.io/monetr/monetr:${BUILD_VERSION} AS upstream

FROM debian:13-slim

# Do not create a default cluster under /var/lib/postgresql; we use /data/postgres
RUN mkdir -p /etc/postgresql-common && \
    echo 'create_main_cluster = false' > /etc/postgresql-common/createcluster.conf

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    locales-all \
    tzdata \
    jq \
    postgresql \
    postgresql-client \
    valkey-server \
    valkey-tools \
    sudo \
    procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1000 monetr && \
    useradd -rm -d /home/monetr -s /bin/bash -g monetr -u 1000 monetr

COPY --from=upstream /usr/bin/monetr /usr/bin/monetr

WORKDIR /home/monetr

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

ARG BUILD_VERSION
ARG BUILD_ARCH
LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}"

USER root
ENTRYPOINT ["/entrypoint.sh"]
