# Gluetun Component

Reusable Flux component for shared Gluetun gateways and automatic port forwarding in `app-template` workloads.

What it provides:

- Automatic port forwarding rotation for services using Gluetun without fixed forwarded ports.
- Multiple port-forwarded apps on the same Gluetun instance.
- Unlimited egress-only apps through the same Gluetun instance.
- Non-root client apps in restricted namespaces, without sidecars.
- Client apps can run on any node and reschedule with a new Gluetun-network IP.
- LAN reuse through Gluetun HTTP/SOCKS proxies when exposed by LoadBalancer Services.

### Design rationale

This component was designed with privacy, security, and GitOps in mind. The goal was to build a zero-config automated shared Gluetun setup, with minimal moving parts, least-privilege client workloads, and no per-app sidecars.

<details>
<summary>Read more ...</summary>
The core idea is that one Gluetun instance becomes one reusable network identity. Any `app-template` workload in the cluster can opt into that identity, and the same Gluetun instance can also be reused from the LAN through its proxies when exposed. This makes it easy to use a specific VPN identity from anywhere on the LAN, from any Kubernetes app, or from any device that can point to the exposed proxy. It also helps maximize limited VPN provider connection slots by reusing a single VPN session across many clients instead of starting a separate VPN tunnel per app.
<br><br>
Existing approaches did not fully match that model. Sidecar-based Gluetun is simple for one app, but it does not scale well, weakens pod security, duplicates VPN configuration everywhere, and makes VPN reuse awkward. solidDoWant’s design is much closer architecturally and also documents a simpler non-HA alternative, but I did not find a complete implemented version of that simpler path. I also wanted this to be packaged as a reusable component to reduce the GitOps surface and make the setup easier to adopt. Starting from that shared VPN gateway model, I kept the useful parts while cutting the operational weight and adapting the design to my existing GitOps infrastructure.
<br><br>
The router/agent split became the smallest clean design that still preserves least privilege: the router handles cluster discovery and app-specific handlers outside the Gluetun pods, while each Gluetun instance only runs a small local agent responsible for applying its own network rules. The component integrates with the existing stack instead of adding a separate VPN platform, using Flux components and the cluster’s networking pieces such as Multus, Cilium, and Envoy where appropriate. It avoids hacky workarounds, supports dynamic port-forward automation, and keeps client apps clean, non-root, and sidecar-less. The result is a practical balance between features, security, and operational simplicity for this cluster.
</details>

## Method Comparison

| Method | This | [solidDoWant](https://github.com/solidDoWant/infra-mk3/tree/master/cluster/gitops/networking/vpn) | [angelnu](https://github.com/angelnu/pod-gateway) | Sidecar |
| :----- | :--: | :---------: | :----: | :-----: |
| Reusable GitOps component | ✅ | ❌ | ❌ | ❌ |
| Dynamic port-forward automation | ✅ | ❌ | ❌ | ❌ |
| Multiple forwarded apps per Gluetun | ✅ | ❌ | ❌ | ❌ |
| Minimal stack | ✅ | ❌ | ❌ | ⚠️ |
| Complexity | Low | High | High | Low |
| Privacy | Strong | Superior | Strong | Strong |
| Security | Strong | Strong | Basic | Basic |
| Client traffic through VPN | ✅ | ✅ | ✅ | ✅  |
| Cluster-Local Traffic | ✅ | ✅ | ✅ | ✅ |
| Inbound port forwarding | ✅ | ✅ | ✅ | ✅  |
| Shared Gluetun gateway | ✅ | ✅ | ✅ | ❌ |
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
- `kubernetes/components/gluetun`: reusable client and Gluetun instance components.

The Usage flow below creates the per-instance and per-app resources automatically.

## Usage

Create Gluetun instances under the Gluetun application tree:

```text
kubernetes/apps/core/gluetun
├── instances
│   ├── <instance-1>.yaml
│   └── <instance-2>.yaml
├── router
└── ks.yaml
```

Use a Flux `Kustomization` to create each Gluetun instance:

```yaml
spec:
  dependsOn:
    - name: gluetun-router
  path: kubernetes/components/gluetun/gateway
  postBuild:
    substitute:
      APP: <instance>
      GLUETUN_GATEWAY_ID: "1"
      GLUETUN_PORT_FORWARDS: "1"
      GLUETUN_PROXIES_ENABLED: "true"
  targetNamespace: gluetun
```

To attach an application to a Gluetun instance, edit the application's `ks.yaml`:

```yaml
spec:
  components:
    - ../../../../../components/gluetun
  dependsOn:
    - name: gluetun-<instance>
  postBuild:
    substitute:
      APP: *app
      GLUETUN_GATEWAY_NAME: gluetun-<instance>
      GLUETUN_GATEWAY_ID: "1"
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
| `GLUETUN_GATEWAY_NAME` *(required)* | none | Gluetun instance name, for example `gluetun-<instance>`. |
| `GLUETUN_GATEWAY_ID` *(required)* | none | Numeric instance ID matching the selected `GLUETUN_GATEWAY_NAME`. |

### Instance component

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | Gluetun instance name and resource prefix. |
| `GLUETUN_GATEWAY_ID` *(required)* | none | Unique numeric ID per Gluetun instance. |
| `GLUETUN_PORT_FORWARDS` | `0` | Number of dynamic forwarded ports requested from Gluetun. |
| `GLUETUN_PROXIES_ENABLED` | `false` | Enables all proxy listeners and LoadBalancer ports. |
| `GLUETUN_HTTPPROXY_ENABLED` | `false` | Enables only the HTTP proxy listener and LoadBalancer port. |
| `GLUETUN_SHADOWSOCKS_ENABLED` | `false` | Enables only the Shadowsocks listener and LoadBalancer port. |
| `GLUETUN_SOCKS5_ENABLED` | `false` | Enables only the SOCKS5 sidecar and LoadBalancer port. |
| `GLUETUN_DNS_SERVICE_IP` | `172.30.0.10` | CoreDNS Service IP override for clusters using a different `kube-dns` Service IP. |
| `GLUETUN_CLUSTER_DNS_ACTION` | `DROP` | Firewall action for CoreDNS on UDP/TCP port 53. Set to `ACCEPT` to allow cluster DNS. |

### Instance secrets

The instance component reads these fields from the `gluetun` 1Password item.

`VPN_SERVICE_PROVIDER` remains the native provider field used by Gluetun.

| Name | Description |
| ---- | ----------- |
| `<INSTANCE>_VPN_SERVICE_PROVIDER` | Provider name used by Gluetun for port forwarding. |
| `<INSTANCE>_WIREGUARD_ADDRESSES` | WireGuard interface address. |
| `<INSTANCE>_WIREGUARD_ENDPOINT_IP` | WireGuard peer endpoint IP. |
| `<INSTANCE>_WIREGUARD_ENDPOINT_PORT` | WireGuard peer endpoint port. |
| `<INSTANCE>_WIREGUARD_PRIVATE_KEY` | WireGuard private key. |
| `<INSTANCE>_WIREGUARD_PUBLIC_KEY` | WireGuard peer public key. |

## Cluster-Local Traffic

Gluetun apps can use selected cluster-local services, but these dependencies are declared by each app rather than by the shared Gluetun component.

### Enable cluster DNS

Cluster DNS is denied by default. Enable it for a gateway in its `ks.yaml`:

```yaml
postBuild:
  substitute:
    GLUETUN_CLUSTER_DNS_ACTION: ACCEPT
```

This uses `172.30.0.10` by default. Set `GLUETUN_DNS_SERVICE_IP` as well when the cluster uses a different `kube-dns` Service IP. Gluetun then permits only UDP/TCP `53` to that address.

> [!IMPORTANT]
> This setting applies to every app sharing the gateway.

### Allow local dependencies

Create a separate `CiliumNetworkPolicy` in the app directory and allow only the required destination and port. For example, an app using CNPG can use:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: ${APP}-local-egress
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/instance: ${APP}
      gluetun.k8s-gitops.io/client-gateway: ${GLUETUN_GATEWAY_NAME}
  egress:
    - toEndpoints:
        - matchLabels:
            cnpg.io/cluster: ${APP}-cnpg
            k8s:io.kubernetes.pod.namespace: ${APP}
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
```

Add the file to the app's `app/kustomization.yaml`.

## Traffic Flow

### Outbound traffic from a VPN client app:

1. The app opts in from its `ks.yaml` with `GLUETUN_GATEWAY_NAME` and `GLUETUN_GATEWAY_ID`.
2. The Gluetun component attaches the app to `gluetun/<gateway>-client@vpn`.
3. Whereabouts gives the app a dynamic `100.100.<gateway-id>.x` address.
4. The app sends all DNS queries to `100.100.<instance>.1`:
   - Kubernetes service names are resolved through CoreDNS on the cluster network.
   - Public names are resolved by Gluetun's encrypted DNS resolver through the VPN tunnel.
5. Internet-bound traffic is routed to the Gluetun gateway at `100.100.<instance>.1`.
6. The Gluetun agent keeps the forwarding and masquerade rules active from `vpn` to `tun0`.
7. Gluetun sends the traffic through the VPN tunnel.

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
- `Role` and `RoleBinding` named `${APP}-gluetun-client`.

### Client app patches:

- Adds required pod affinity to schedule on the VPN node.
- Adds the Multus network annotation for `gluetun/${GLUETUN_GATEWAY_NAME}-client@vpn`.
- Sets `dnsPolicy: None`.
- Sets the DNS nameserver to `100.100.${GLUETUN_GATEWAY_ID}.1`.

## Notes

- Adapt it as needed for clusters using different networking or secret-management stacks.
