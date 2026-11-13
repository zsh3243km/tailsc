#!/bin/sh
set -eu
SOCKET="${TS_SOCKET:-/run/tailscale/tailscaled.sock}"
tailscale --socket="$SOCKET" status >/dev/null 2>&1
