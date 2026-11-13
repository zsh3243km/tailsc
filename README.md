# Railway Tailscale Userspace Exit Node

This project runs **Tailscale as a userspace/netstack exit node** on Railway.
It is not a standalone WireGuard server.

## What this does

- Runs `tailscaled` with `--tun=userspace-networking`.
- Authenticates using a Tailscale auth key supplied as a Railway variable.
- Advertises the node as an exit node.
- Does not require `/dev/net/tun`, `NET_ADMIN`, privileged mode, or an inbound UDP port.
- Can use Tailscale DERP relays when a direct peer-to-peer UDP path is unavailable.

Tailscale documents userspace routers/exit nodes here:
https://tailscale.com/docs/reference/kernel-vs-userspace-routers

Railway TCP Proxy is TCP-only and is not used by this project:
https://docs.railway.com/networking/tcp-proxy

## Deploy on Railway

1. Create a new Railway project and deploy this folder/repository using the included Dockerfile.
2. In Tailscale Admin Console, create an auth key:
   https://login.tailscale.com/admin/settings/keys
   Prefer a short-lived, reusable key only if you need repeated provisioning. Do not commit it.
3. In Railway, add these service variables:
   - `TS_AUTHKEY` = your Tailscale auth key
   - `TS_HOSTNAME` = `railway-exit-node` (optional)
4. Add a Railway Volume mounted at `/data`. This preserves the Tailscale node identity between restarts.
5. Deploy and inspect the deployment logs. A successful startup prints the Tailscale status and IPv4 address.
6. Open https://login.tailscale.com/admin/machines and locate `railway-exit-node`.
7. If the admin console shows an exit-node approval/action, approve the advertised exit route.
8. On your Windows/macOS/mobile Tailscale client, select `railway-exit-node` under Exit Node.
9. Verify the public IP from the client using https://ipinfo.io or https://icanhazip.com.

## Important limitations

- **This is a Tailscale exit node, not a generic public SOCKS5/HTTP proxy.**
- **This is not a standalone WireGuard server.** Railway's public TCP Proxy does not transport UDP, which standard WireGuard requires.
- Userspace mode can relay TCP/UDP connections through Tailscale's netstack, but it is not identical to kernel-mode packet forwarding. Some protocols and behaviors that depend on raw IP packets may differ.
- Tailscale may use DERP relays if direct UDP connectivity cannot be established. This can increase latency and reduce throughput.
- Railway may change platform behavior, resource limits, or networking constraints. This package cannot guarantee a specific speed or uninterrupted availability.
- Do not expose a new public proxy port; the Tailscale control/DERP connections are initiated outbound.

## Troubleshooting

### No `TS_AUTHKEY`
Set the Railway variable `TS_AUTHKEY` and redeploy.

### Node appears in Tailscale but is not selectable as an exit node
Check the machine's route/exit-node approval in the Tailscale admin console. Confirm the logs show the `tailscale up` command succeeded.

### Node reconnects with a new identity after redeploy
Ensure a Railway Volume is mounted at `/data`. Do not use an ephemeral filesystem for the state file if you want a stable node identity.

### No direct connection / DERP relay
This can be normal on hosted platforms. Check `tailscale status` and `tailscale ping <peer>` from a tailnet device. DERP fallback is encrypted but may be slower.

### WireGuard app cannot connect to this service
Expected: this project does not listen for public WireGuard UDP packets and cannot be configured as a standard WireGuard endpoint through Railway TCP Proxy.

## Security

- Keep `TS_AUTHKEY` only in Railway Variables; never put it in source control or logs.
- Use an auth key with the shortest practical expiry and least privilege.
- If the key is exposed, revoke it in the Tailscale admin console.
- Restrict tailnet access using Tailscale access controls.
