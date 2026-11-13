#!/bin/sh
set -eu

: "${TS_STATE_DIR:=/data}"
: "${TS_SOCKET:=/run/tailscale/tailscaled.sock}"
: "${TS_HOSTNAME:=railway-smart-exit}"
: "${TS_DIAG_INTERVAL:=60}"
: "${TS_NETCHECK_INTERVAL:=600}"

if [ -z "${TS_AUTHKEY:-}" ]; then
  echo "[fatal] TS_AUTHKEY is missing. Add it in Railway Variables."
  exit 1
fi

mkdir -p "$TS_STATE_DIR" "$(dirname "$TS_SOCKET")"

echo "[startup] Tailscale userspace exit node"
echo "[startup] hostname=$TS_HOSTNAME"
echo "[startup] state_dir=$TS_STATE_DIR"
echo "[startup] diag_interval=${TS_DIAG_INTERVAL}s netcheck_interval=${TS_NETCHECK_INTERVAL}s"
echo "[startup] CPU quota: $(cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo unknown)"
echo "[startup] memory limit: $(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo unknown)"

# No /dev/net/tun is required. This is Tailscale's userspace/netstack mode.
tailscaled \
  --tun=userspace-networking \
  --state="$TS_STATE_DIR/tailscaled.state" \
  --socket="$TS_SOCKET" \
  --verbose="${TS_VERBOSE:-0}" &
TAILSCALED_PID=$!

cleanup() {
  echo "[shutdown] stopping tailscaled"
  kill "$TAILSCALED_PID" 2>/dev/null || true
  wait "$TAILSCALED_PID" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

echo "[startup] waiting for local Tailscale daemon..."
i=0
until tailscale --socket="$TS_SOCKET" status >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "[fatal] tailscaled did not become ready"
    exit 1
  fi
  sleep 1
done

# Keep the flags explicit and predictable. Do not force MTU or kernel sysctls:
# Railway's interface MTU is platform-managed and an incorrect override can
# make throughput worse or break connectivity.
tailscale --socket="$TS_SOCKET" up \
  --auth-key="$TS_AUTHKEY" \
  --hostname="$TS_HOSTNAME" \
  --advertise-exit-node \
  --accept-dns=false

echo "[startup] tailscale is up; current status:"
tailscale --socket="$TS_SOCKET" status || true

# Diagnostics/optimizer runs alongside tailscaled and never changes network
# settings automatically. It records evidence for safe tuning.
TS_SOCKET="$TS_SOCKET" \
TS_DIAG_INTERVAL="$TS_DIAG_INTERVAL" \
TS_NETCHECK_INTERVAL="$TS_NETCHECK_INTERVAL" \
/app/scripts/optimizer.sh &
OPT_PID=$!

wait "$TAILSCALED_PID"
