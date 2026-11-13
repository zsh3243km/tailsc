#!/bin/sh
set -eu

: "${TS_SOCKET:=/run/tailscale/tailscaled.sock}"
: "${TS_DIAG_INTERVAL:=60}"
: "${TS_NETCHECK_INTERVAL:=600}"

ticks() {
  # Return user+system CPU ticks for the tailscaled process, if present.
  for p in /proc/[0-9]*; do
    [ -r "$p/comm" ] || continue
    name=$(cat "$p/comm" 2>/dev/null || true)
    if [ "$name" = "tailscaled" ]; then
      awk '{print $14+$15}' "$p/stat" 2>/dev/null || echo 0
      return
    fi
  done
  echo 0
}

echo "[optimizer] adaptive diagnostics started; no risky automatic MTU/sysctl changes will be applied"
last_netcheck=0
last_ticks="$(ticks)"
last_time="$(date +%s)"

while :; do
  sleep "$TS_DIAG_INTERVAL"
  now="$(date +%s)"
  current_ticks="$(ticks)"
  elapsed=$((now - last_time))
  delta_ticks=$((current_ticks - last_ticks))
  [ "$delta_ticks" -lt 0 ] && delta_ticks=0

  # Linux USER_HZ is normally 100; report an approximate single-core percentage.
  if [ "$elapsed" -gt 0 ]; then
    cpu_pct=$((delta_ticks * 100 / elapsed))
  else
    cpu_pct=0
  fi

  mem_current="$(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo unknown)"
  mem_max="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo unknown)"
  cpu_quota="$(cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo unknown)"
  load="$(cat /proc/loadavg 2>/dev/null || echo unknown)"

  echo "[optimizer] cpu_approx=${cpu_pct}%_of_one_core elapsed=${elapsed}s cgroup_cpu=${cpu_quota} memory=${mem_current}/${mem_max} load=${load}"

  for f in /sys/class/net/*/mtu; do
    [ -r "$f" ] || continue
    iface="${f%/mtu}"
    iface="${iface##*/}"
    mtu="$(cat "$f" 2>/dev/null || echo unknown)"
    rx="$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)"
    tx="$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)"
    echo "[optimizer] interface=$iface mtu=$mtu rx_bytes=$rx tx_bytes=$tx"
  done

  if tailscale --socket="$TS_SOCKET" status >/dev/null 2>&1; then
    echo "[optimizer] tailscale_status=healthy"
  else
    echo "[optimizer] WARNING tailscale_status=unavailable"
  fi

  if [ $((now - last_netcheck)) -ge "$TS_NETCHECK_INTERVAL" ]; then
    echo "[optimizer] running periodic netcheck"
    tailscale --socket="$TS_SOCKET" netcheck 2>&1 | sed 's/^/[netcheck] /' || true
    last_netcheck="$now"
  fi

  last_ticks="$current_ticks"
  last_time="$now"
done
