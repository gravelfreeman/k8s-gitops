# VPN component

Reusable VPN gateway component for bjw-s app-template workloads.

```yaml
spec:
  components:
    - ../../../../../components/common/system
    - ../../../../../components/volsync
    - ../../../../../components/vpn
  dependsOn:
    - name: multus-networks
  postBuild:
    substitute:
      APP: *app
      VPN_GATEWAY: alfa
      VPN_GATEWAY_IP: 100.100.1.1
```

## Resources

- Creates a **CiliumNetworkPolicy** named `${APP}-egress`
- Patches app-template `defaultPodOptions`
