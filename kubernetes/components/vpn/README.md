# VPN components

Reusable VPN gateway components for bjw-s app-template workloads.

```yaml
spec:
  components:
    - ../../../../../components/common/system
    - ../../../../../components/volsync
    - ../../../../../components/vpn/alfa
  dependsOn:
    - name: multus-networks
  postBuild:
    substitute:
      APP: *app
```

Available gateways:

- DNS `100.100.1.1`: `vpn/alfa`
- DNS `100.100.2.1`: `vpn/bravo`
- DNS `100.100.3.1`: `vpn/charlie`
- DNS `100.100.4.1`: `vpn/delta`
- DNS `100.100.5.1`: `vpn/echo`

## Resources

- Creates a **CiliumNetworkPolicy** named `${APP}-vpn-egress`
- Patches app-template `defaultPodOptions`
