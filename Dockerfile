FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl iproute2 iptables \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://tailscale.com/install.sh | sh

COPY scripts/start.sh /usr/local/bin/start-tailscale
RUN chmod +x /usr/local/bin/start-tailscale \
 && mkdir -p /data /run/tailscale

ENV TS_STATE_DIR=/data
ENV TS_SOCKET=/run/tailscale/tailscaled.sock
ENV TS_HOSTNAME=railway-exit-node

CMD ["/usr/local/bin/start-tailscale"]
