# VPN Component

Reusable VPN egress and port-forward component for `app-template` workloads, with a zero-config router that links apps, VPN gateways, forwarded ports, and handlers.

What it provides

- Automatic port forwarding rotation for VPN services without fixed forwarded ports.
- Multiple port-forwarded apps on the same VPN instance.
- Unlimited egress-only apps through the same VPN instance.
- Non-root client apps in restricted namespaces, without sidecars.
- Client apps can run on any node and reschedule with a new VPN-network IP.
- LAN reuse through Gluetun HTTP/SOCKS proxies when exposed by LoadBalancer Services.

## Method Comparison

| Method | This | solidDoWant | angelnu | Sidecar |
| :----- | :--: | :---------: | :----: | :-----: |
| Complexity | Moderate | Advanced | Intermediate | Beginner |
| Privacy | Strong | **Best** | Strong | Strong |
| Security | Strong | Strong | Basic | Basic |
| Minimal stack | ✅ | ❌ | ❌ | ✅ |
| Moving parts for 5 clients**¹** | ~6 | ~20+ | ~15+ | ~5 |
| Moving parts for 100 clients**²** | ~24 | ~80+ | ~300+ | ~100 |
| Dynamic port-forward automation | ✅ | ❌ | ❌ | ❌ |
| Multiple forwarded apps per VPN | ✅ | ❌ | ❌ | ❌ |
| Inbound port forwarding | ✅ | ✅ | ✅ | ✅  |
| VPN egress | ✅ | ✅ | ✅ | ✅  |
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

**¹** Scenario A: 5 VPN client apps, 1 port-forwarded app, and 1 shared Gluetun instance.

**²** Scenario B: 100 VPN client apps, 10 port-forwarded apps, and 10 shared Gluetun instances.

## Requirements

- At least one `Gluetun` instance configured with the `gluetun-router` sidecar.
- The shared `gluetun-router` resources installed in the *Gluetun* namespace.
- *Whereabouts* installed for dynamic IP allocation on client networks.

## Usage

```yaml
components:
  - ../../../../../components/vpn
dependsOn:
  - name: gluetun-<instance-name>
postBuild:
  substitute:
    APP: *app
    VPN_GATEWAY: <instance-name>
    VPN_GATEWAY_IP: 100.100.1.1
```

Applications that need an inbound forwarded port expose their app-template Service port as `forward-tcp` and/or `forward-udp`:

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

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | App name and resource prefix. |
| `VPN_GATEWAY` *(required)* | none | Gluetun gateway name, `<instance-name>`. |
| `VPN_GATEWAY_IP` *(required)* | none | Gateway IP on the client VPN network, for example `100.100.1.1`. |

## Traffic Flow

#### Outbound traffic from a VPN client app:

1. The app pod gets a secondary `vpn` interface from `gluetun/gluetun-<gateway>-client`.
2. Whereabouts assigns the app a dynamic IP from the gateway client subnet.
3. The app routes internet-bound traffic through `VPN_GATEWAY_IP`.
4. The Gluetun pod receives that traffic on its own `vpn` interface from `gluetun/gluetun-<gateway>-gateway`.
5. `gluetun-router` allows forwarding from `vpn` to the VPN tunnel interface and masquerades the client subnet.
6. Gluetun sends the traffic through the VPN tunnel to the internet.

#### Inbound traffic from an internet peer:

1. Gluetun receives the current forwarded VPN port from its VPN connection.
2. `gluetun-router` reads that port from the local Gluetun control API.
3. `gluetun-router` discovers opted-in apps with `vpn.k8s-gitops.io/port-forward-gateway: <gateway>`.
4. It reads the app IP from the `gluetun-<gateway>-client` network-status annotation.
5. It reads the app Service ports named `forward-tcp` and/or `forward-udp`.
6. It creates DNAT/FORWARD rules from the forwarded VPN port to the app IP and Service port.
7. It runs the matching handler so the app can learn the current external forwarded port when needed.

## Gluetun Router

`gluetun-router` is a sidecar that runs beside each Gluetun container. It reads the forwarded VPN ports from the local Gluetun control API, discovers opted-in app pods from Kubernetes, programs the DNAT/FORWARD rules, and calls an app-specific handler when a forwarded port is assigned.

Discovery is convention-based:

- The Gluetun pod has `network.k8s-gitops.io/vpn-gateway: <gateway>`.
- This component adds `vpn.k8s-gitops.io/port-forward-gateway: <gateway>` to app pods.
- This component attaches app pods to `gluetun/gluetun-<gateway>-client@vpn`.
- The app Service exposes `forward-tcp` and/or `forward-udp` when inbound forwarding is needed.
- The handler name is derived from the app container image basename.

For example, an app container image ending in `qbittorrent` uses `/router/qbittorrent.sh`.

Handlers are stored in `path/to/gluetun/router/handlers` and merged into the `gluetun-router` ConfigMap.

To add a handler:

1. Create `handlers/<image-basename>.sh`.
2. Add it to the `configMapGenerator.files` list.
3. Use the environment variables provided by the router.

Handler environment:

| Name | Description |
| ---- | ----------- |
| `SLOT` | Stable assignment index for the gateway. |
| `HANDLER` | Handler name. |
| `EXTERNAL_PORT` | Current forwarded VPN port. |
| `TARGET_IP` | App IP on `gluetun-<gateway>-client`. |
| `TARGET_PORT` | First configured `forward-tcp` or `forward-udp` Service port. |
| `VPN_GATEWAY` | Gluetun gateway name. |

Apps without `forward-tcp` or `forward-udp` are still routed through the VPN for egress, but are ignored by the port-forward logic.

## Gluetun

In this setup, Gluetun is the VPN gateway pod. It receives the static `gluetun-<gateway>-gateway` Multus address, exposes the local control API to the router sidecar, and shares the pod network namespace with the router so the router can manage forwarding rules.

Only the Gluetun-specific additions needed for this routing model are shown here:

```yaml
      gluetun:
        env:
          VPN_PORT_FORWARDING: on
          VPN_PORT_FORWARDING_PORTS_COUNT: "4"
          HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH: /run/secrets/gluetun/config.toml
```
```yaml
      router:
        image:
          repository: ghcr.io/nicolaka/netshoot
          tag: v0.15
        command: ["/bin/sh", "/router/router.sh"]
        env:
          GLUETUN_API_KEY:
            valueFrom:
              secretKeyRef:
                name: gluetun-<instance-name>-secret
                key: GLUETUN_API_KEY
          VPN_GATEWAY:
            valueFrom:
              fieldRef:
                fieldPath: metadata.labels['network.k8s-gitops.io/vpn-gateway']
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add: [NET_ADMIN]
            drop: [ALL]
          readOnlyRootFilesystem: true
          runAsGroup: 0
          runAsUser: 0
```
```yaml
    pod:
      annotations:
        k8s.v1.cni.cncf.io/networks: gluetun/<gluetun-instance>-gateway@vpn
      labels:
        network.k8s-gitops.io/vpn-gateway: <instance-name>
      automountServiceAccountToken: true
      serviceAccountName: gluetun-router
```
```yaml
persistence:
  router:
    type: configMap
    name: gluetun-router
    advancedMounts:
      gluetun-<instance-name>:
        router:
          - path: /router
            readOnly: true
```

The Gluetun control API role only needs access to the port-forward endpoint:

```toml
[[roles]]
name = "port-forward"
routes = ["GET /v1/portforward"]
auth = "apikey"
apikey = "<from-secret>"
```

## Resources

- `CiliumNetworkPolicy` named `${APP}-egress`
- Attaches app pods to `gluetun/gluetun-${VPN_GATEWAY}-client@vpn`
- Sets app DNS to `${VPN_GATEWAY_IP}`
- Adds `network.k8s-gitops.io/vpn-egress: ${VPN_GATEWAY}` for egress policy selection
- Adds `vpn.k8s-gitops.io/port-forward-gateway: ${VPN_GATEWAY}` for Gluetun router discovery
- Patches app-template `defaultPodOptions`

## Notes

- `<instance-name>` refers to the Gluetun instance's name.
