#!/bin/sh
set -eu

if [ -z "${TS_AUTHKEY:-}" ]; then
  echo "ERROR: TS_AUTHKEY is required. Create an auth key in the Tailscale admin console."
  exit 1
fi

mkdir -p "$TS_STATE_DIR" "$(dirname "$TS_SOCKET")"

echo "[1/4] Starting Tailscale in userspace networking mode..."
tailscaled \
  --tun=userspace-networking \
  --state="${TS_STATE_DIR}/tailscaled.state" \
  --socket="$TS_SOCKET" &
TAILSCALED_PID=$!

cleanup() {
  echo "Stopping tailscaled..."
  kill "$TAILSCALED_PID" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

echo "[2/4] Waiting for tailscaled socket..."
i=0
until [ -S "$TS_SOCKET" ]; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "ERROR: tailscaled socket did not become ready."
    exit 1
  fi
  sleep 1
done

echo "[3/4] Authenticating and advertising this node as an exit node..."
# This is a userspace/netstack exit node; it does not require /dev/net/tun,
# NET_ADMIN, host networking, or a public inbound UDP port.
tailscale --socket="$TS_SOCKET" up \
  --auth-key="$TS_AUTHKEY" \
  --hostname="${TS_HOSTNAME}" \
  --advertise-exit-node \
  --accept-dns=false

echo "[4/4] Tailscale status:"
tailscale --socket="$TS_SOCKET" status
echo "Tailscale IPv4:"
tailscale --socket="$TS_SOCKET" ip -4 || true
echo
echo "READY: approve this machine as an exit node in the Tailscale admin console."
echo "Keep this process running; use the Railway volume mounted at /data to persist identity."

wait "$TAILSCALED_PID"
