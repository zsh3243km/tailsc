FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TS_STATE_DIR=/data \
    TS_SOCKET=/run/tailscale/tailscaled.sock \
    TS_HOSTNAME=railway-smart-exit \
    TS_DIAG_INTERVAL=60 \
    TS_NETCHECK_INTERVAL=600 \
    TS_LOG_LEVEL=info

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl iproute2 procps util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://tailscale.com/install.sh | sh

WORKDIR /app
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh \
    && mkdir -p /data /run/tailscale

VOLUME ["/data"]

ENTRYPOINT ["/app/scripts/start.sh"]
