# Gluetun

Reusable *bjw-s* **app-template** sidecar component for workloads that need a *Gluetun*
VPN container in the same Pod.

## Usage

Add the component to the app Flux `Kustomization`:

```yaml
spec:
  components:
    - ../../../components/common
    - ../../../components/gluetun
  postBuild:
    substitute:
      APP: *app
      POD_SECURITY_ENFORCE: privileged
```

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `APP` | Required | App/controller name to patch and 1Password item to read. |
| `POD_SECURITY_ENFORCE` | `restricted` | Must be overridden to `privileged`. |
| `GLUETUN_VPN_PORT_FORWARDING` | `on` | Enable or disable provider port forwarding. |

## Resources

- Adds a `gluetun` sidecar container to `controllers.${APP}`.
- Adds a `gluetun` ClusterIP service entry for the control server API on port `8000`.
- Adds `${APP}-gluetun-secret`, sourced from the `${APP}` 1Password item.
- Mounts `/dev/net/tun` from the node as a character device.

## Notes

- The target HelmRelease requires a `${APP}` controller and existing `controllers.${APP}.containers`, `persistence`, and `service` maps.
- Requires privileged namespace policy because Gluetun needs `/dev/net/tun` and `NET_ADMIN`.
- `FIREWALL_INPUT_PORTS`'s `<app port>` is read from `spec.values.service.app.ports.http.port`.
- The `${APP}` 1Password item must include `GLUETUN_API_KEY`, `VPN_SERVICE_PROVIDER`, and `WIREGUARD_PRIVATE_KEY` fields.
