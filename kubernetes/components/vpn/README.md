# VPN Component

Reusable Flux component for shared VPN and automatic port forwarding in `app-template` workloads.

What it provides:

- Automatic port forwarding rotation for VPN services without fixed forwarded ports.
- Multiple port-forwarded apps on the same VPN instance.
- Unlimited egress-only apps through the same VPN instance.
- Non-root client apps in restricted namespaces, without sidecars.
- Client apps can run on any node and reschedule with a new VPN-network IP.
- LAN reuse through Gluetun HTTP/SOCKS proxies when exposed by LoadBalancer Services.

### Design rationale

This component was designed with privacy, security, and GitOps in mind. The goal was to build a zero-config automated shared VPN setup, with minimal moving parts, least-privilege client workloads, and no per-app sidecars.

<details>
<summary>Read more ...</summary>
The core idea is that one VPN instance becomes one reusable network identity. Any `app-template` workload in the cluster can opt into that identity, and the same VPN instance can also be reused from the LAN through Gluetun proxies when exposed. This makes it easy to use a specific VPN identity from anywhere on the LAN, from any Kubernetes app, or from any device that can point to the exposed proxy. It also helps maximize limited VPN provider connection slots by reusing a single VPN session across many clients instead of starting a separate VPN tunnel per app.
<br><br>
Existing approaches did not fully match that model. Sidecar-based Gluetun is simple for one app, but it does not scale well, weakens pod security, duplicates VPN configuration everywhere, and makes VPN reuse awkward. solidDoWant’s design is much closer architecturally and also documents a simpler non-HA alternative, but I did not find a complete implemented version of that simpler path. I also wanted this to be packaged as a reusable component to reduce the GitOps surface and make the setup easier to adopt. Starting from that shared VPN gateway model, I kept the useful parts while cutting the operational weight and adapting the design to my existing GitOps infrastructure.
<br><br>
The router/agent split became the smallest clean design that still preserves least privilege: the router handles cluster discovery and app-specific handlers outside the VPN pods, while each Gluetun instance only runs a small local agent responsible for applying its own network rules. The component integrates with the existing stack instead of adding a separate VPN platform, using Flux components and the cluster’s networking pieces such as Multus, Cilium, and Envoy where appropriate. It avoids hacky workarounds, supports dynamic port-forward automation, and keeps client apps clean, non-root, and sidecar-less. The result is a practical balance between features, security, and operational simplicity for this cluster.
</details>

## Method Comparison

| Method | This | [solidDoWant](https://github.com/angelnu/pod-gateway) | [angelnu](https://github.com/angelnu/pod-gateway) | Sidecar |
| :----- | :--: | :---------: | :----: | :-----: |
| Reusable GitOps component | ✅ | ❌ | ❌ | ❌ |
| Dynamic port-forward automation | ✅ | ❌ | ❌ | ❌ |
| Multiple forwarded apps per VPN | ✅ | ❌ | ❌ | ❌ |
| Minimal stack | ✅ | ❌ | ❌ | ⚠️ |
| Complexity | Low | High | High | Low |
| Privacy | Strong | Superior | Strong | Strong |
| Security | Strong | Strong | Basic | Basic |
| Client traffic through VPN | ✅ | ✅ | ✅ | ✅  |
| Inbound port forwarding | ✅ | ✅ | ✅ | ✅  |
| Shared VPN gateway | ✅ | ✅ | ✅ | ❌ |
| Node-independent clients | ✅ | ✅ | ✅ | ❌ |
| Gateway health routing | ⚠️ | ✅ | ⚠️ | ❌ |
| Zero-config app opt-in | ✅ | ✅ | ❌ | ❌ |
| Restricted client namespaces | ✅ | ✅ | ❌ | ❌ |
| High availability | ❌ | ✅ | ❌ | ❌ |
| Multi-exit throughput | ❌ | ✅ | ❌ | ❌ |
| Multi-exit DDNS | ❌ | ✅ | ❌ | ❌ |
| Ingress/egress load balancing | ❌ | ✅ | ❌ | ❌ |
| Router VIP failover | ❌ | ✅ | ❌ | ❌ |

✅ supported · ⚠️ partial · ❌ not supported

## Requirements

- `cilium`: handles the main network, policies, and optional Gluetun proxy LoadBalancers.
- `external-secrets`: syncs external secrets and generates runtime tokens for the component.
- `multus`: creates the internal VPN network and connects Gluetun and client pods to it.
- `node-network-operator`: creates per-node bridge/VXLAN links for the VPN network.
- `whereabouts`: assigns dynamic IPs to client pods on each VPN client network.

Required *Multus* CNI paths in `HelmRelease`:

```yaml
values:
  cni:
    binPath: /opt/cni/bin
    netPath: /etc/cni/net.d
```

Required *node-network-operator* `Link` to be created:

```yaml
apiVersion: nodenetworkoperator.soliddowant.dev/v1alpha1
kind: Link
metadata:
  name: vpn-underlay
spec:
  interfaceName: <node-underlay-interface>
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
  unmanaged: {}
```

## Installation

Once you've met all requirements, copy or adapt these repo paths into your cluster GitOps tree:

- `kubernetes/apps/core/gluetun/router`: shared router, agent scripts, handlers, and token generator.
- `kubernetes/components/vpn`: reusable client and Gluetun instance components.

The Usage flow below creates the per-instance and per-app resources automatically.

## Usage

Create VPN instances under the Gluetun application tree:

```text
kubernetes/apps/core/gluetun
├── instances
│   ├── <instance-1>.yaml
│   └── <instance-2>.yaml
├── router
└── ks.yaml
```

Use a Flux `Kustomization` to create each VPN instance:

```yaml
spec:
  dependsOn:
    - name: gluetun-router
  path: kubernetes/components/vpn/instance
  postBuild:
    substitute:
      APP: <instance>
      VPN_INSTANCE: "1"
      VPN_PORT_FORWARDS: "1"
      VPN_PROXIES_ENABLED: "true"
  targetNamespace: gluetun
```

To attach an application to a VPN instance, edit the application's `ks.yaml`:

```yaml
spec:
  components:
    - ../../../../../components/vpn
  dependsOn:
    - name: gluetun-<vpn-instance>
  postBuild:
    substitute:
      APP: *app
      VPN_GATEWAY: gluetun-<vpn-instance>
      VPN_INSTANCE: "1"
```

Applications that requires port forwarding must expose their service port as `forward-tcp/udp`:

```yaml
service:
  app:
    ports:
      forward-tcp:
        port: 6881
        protocol: TCP
      forward-udp:
        port: 6881
        protocol: UDP
```

## Variables

### Client component

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | Client app name and resource prefix. |
| `VPN_GATEWAY` *(required)* | none | VPN instance name, for example `gluetun-<instance>`. |
| `VPN_INSTANCE` *(required)* | none | Numeric instance ID matching the selected `VPN_GATEWAY`. |

### Instance component

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | Gluetun instance name and resource prefix. |
| `VPN_INSTANCE` *(required)* | none | Unique numeric instance ID per VPN instance. |
| `VPN_PORT_FORWARDS` | `0` | Number of dynamic forwarded ports requested from Gluetun. |
| `VPN_PROXIES_ENABLED` | `false` | Enables all proxy listeners and LoadBalancer ports. |
| `VPN_HTTPPROXY_ENABLED` | `false` | Enables only the HTTP proxy listener and LoadBalancer port. |
| `VPN_SHADOWSOCKS_ENABLED` | `false` | Enables only the Shadowsocks listener and LoadBalancer port. |
| `VPN_SOCKS5_ENABLED` | `false` | Enables only the SOCKS5 sidecar and LoadBalancer port. |

### Instance secrets

The instance component reads these fields from the `gluetun` 1Password item.

| Name | Description |
| ---- | ----------- |
| `<INSTANCE>_VPN_SERVICE_PROVIDER` | Provider name used by Gluetun for port forwarding. |
| `<INSTANCE>_WIREGUARD_ADDRESSES` | WireGuard interface address. |
| `<INSTANCE>_WIREGUARD_ENDPOINT_IP` | WireGuard peer endpoint IP. |
| `<INSTANCE>_WIREGUARD_ENDPOINT_PORT` | WireGuard peer endpoint port. |
| `<INSTANCE>_WIREGUARD_PRIVATE_KEY` | WireGuard private key. |
| `<INSTANCE>_WIREGUARD_PUBLIC_KEY` | WireGuard peer public key. |

## Traffic Flow

### Outbound traffic from a VPN client app:

1. The app opts in from its `ks.yaml` with `VPN_GATEWAY` and `VPN_INSTANCE`.
2. The VPN component attaches the app to `gluetun/<gateway>-client@vpn`.
3. Whereabouts gives the app a dynamic `100.100.<instance>.x` address.
4. Internet-bound traffic is routed to the Gluetun gateway at `100.100.<instance>.1`.
5. The Gluetun agent keeps the forwarding and masquerade rules active from `vpn` to `tun0`.
6. Gluetun sends the traffic through the VPN tunnel.

### Inbound traffic from an internet peer:

1. Gluetun receives the current forwarded ports from the VPN connection.
2. The central `gluetun-router` discovers running gateways and opted-in apps.
3. Apps with `forward-tcp` and/or `forward-udp` Service ports become port-forward targets.
4. The router sends those targets to the matching Gluetun agent.
5. The agent reads the current forwarded ports from the local Gluetun API.
6. The agent applies DNAT/FORWARD rules inside the Gluetun pod network namespace.
7. The agent returns the active port assignments to the router.
8. The router runs the matching app handler when the app needs to learn the public port.

## Resources

### Gluetun instance resources:

- `HelmRelease` named `${APP}` with `gluetun`, `agent`, and optional `socks5` containers.
- `ExternalSecret` named `${APP}-secret` for Gluetun runtime files and API key.
- `ExternalSecret` named `${APP}-agent` for the agent token.
- `Role` and `RoleBinding` named `${APP}-agent-reader` so the router can read the agent token.
- `NetworkAttachmentDefinition` named `${APP}-gateway` for the Gluetun gateway interface.
- `NetworkAttachmentDefinition` named `${APP}-client` for VPN client pods.
- `Link` named `${APP}-bridge` for the per-node bridge.
- `Link` named `${APP}-vxlan` for the per-node VXLAN interface.

### Client app resources:

- `CiliumNetworkPolicy` named `${APP}-egress`.
- `Role` and `RoleBinding` named `${APP}-vpn-evictor`.

### Client app patches:

- Adds required pod affinity to schedule on the VPN node.
- Adds the Multus network annotation for `gluetun/${VPN_GATEWAY}-client@vpn`.
- Sets `dnsPolicy: None`.
- Sets the DNS nameserver to `100.100.${VPN_INSTANCE}.1`.
- Adds `network.k8s-gitops.io/vpn-egress: ${VPN_GATEWAY}`.
- Adds `vpn.k8s-gitops.io/port-forward-gateway: ${VPN_GATEWAY}`.

## Notes

- Adapt it as needed for clusters using different networking or secret-management stacks.
