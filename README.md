# Railway Tailscale Smart Exit Node

A diagnostic-focused, self-monitoring Tailscale **userspace/netstack exit node** for Railway.

## What is improved

- Continuous health checks against the local Tailscale daemon.
- Periodic CPU, memory, load, interface byte-counter and MTU measurements.
- Periodic `tailscale netcheck` output in Railway deployment logs.
- Persistent node state under `/data`.
- No dependency on `/dev/net/tun`, `NET_ADMIN`, privileged mode, or a public inbound UDP port.
- No arbitrary MTU/sysctl changes that could make networking worse.

## Important: what "self-speed optimization" can and cannot do

There is no safe universal switch that makes a userspace exit node faster. The optimizer collects measurements and identifies likely bottlenecks; it deliberately does **not** change MTU, routes, congestion control, or kernel networking settings automatically. Those changes are platform- and path-dependent, and a bad value can reduce throughput or disconnect the node.

Your current Railway measurements showed:
- Tailscale peer connection is `direct`, not DERP.
- `railnet0` MTU is 1316 and `tunl0` MTU is 1480.
- Container CPU quota is 2 cores and memory limit is about 1 GiB.
- A short CPU sampling showed low `tailscaled` CPU use during that sample.
These facts do not yet prove the MTU is the bottleneck. The logs from this version are intended to collect comparable data during an actual download.

The project remains userspace mode because the current Railway container has no `/dev/net/tun`. Root inside the container does not create host TUN device access. Kernel-mode Tailscale would require host/device capabilities Railway may not provide.

## Deploy

1. Deploy this folder/repository to Railway using the included Dockerfile.
2. Add a Railway Volume mounted at `/data`.
3. Add Railway Variable `TS_AUTHKEY` with a Tailscale auth key. Do not put the key in source control.
4. Optionally set `TS_HOSTNAME=railway-smart-exit`.
5. Deploy and wait for logs containing `[startup] tailscale is up`.
6. In the Tailscale admin console, approve the advertised exit node if prompted.
7. Select `railway-smart-exit` as Exit Node on your client.

No Railway TCP Proxy is required. Do not expose a public port for this service.

## Optional variables

| Variable | Default | Purpose |
|---|---:|---|
| `TS_HOSTNAME` | `railway-smart-exit` | Tailnet machine name |
| `TS_DIAG_INTERVAL` | `60` | Seconds between resource/interface snapshots |
| `TS_NETCHECK_INTERVAL` | `600` | Seconds between Tailscale network checks |
| `TS_VERBOSE` | `0` | Tailscaled verbosity |

## How to use the optimizer logs

During a client download, inspect Railway logs:
- `cpu_approx=...`: approximate `tailscaled` CPU usage as a percentage of one core.
- `memory=...`: cgroup memory usage and limit.
- `interface=... mtu=... rx_bytes=... tx_bytes=...`: interface MTU and cumulative counters.
- `[netcheck]`: UDP, public address, IPv4/IPv6 and DERP diagnostics.
- `tailscale_status=healthy`: local daemon responds.

For useful comparison, capture logs during:
1. A download with the Exit Node enabled.
2. A direct download with Exit Node disabled.

## Limitations

- This is not a standalone public WireGuard server. Railway TCP Proxy is TCP-only, while standard WireGuard requires UDP.
- This is not a generic SOCKS5/HTTP proxy.
- Userspace mode can act as an exit node but differs from kernel-mode packet forwarding and may have lower throughput or protocol limitations.
- Direct peer connectivity does not guarantee high throughput; packet size, MTU/PMTU, routing, host constraints and the client network can still matter.
- No fixed speed is guaranteed.

## Troubleshooting

### Node not selectable as Exit Node
Check Tailscale admin approval and Railway logs for `tailscale is up`.

### State resets after redeploy
Ensure a Railway Volume is mounted at `/data`.

### Need to inspect status manually
Railway Shell:
```sh
tailscale --socket=/run/tailscale/tailscaled.sock status
tailscale --socket=/run/tailscale/tailscaled.sock netcheck
```

### Security
Keep `TS_AUTHKEY` in Railway Variables only. Revoke exposed keys and restrict access using tailnet ACL/grants.
