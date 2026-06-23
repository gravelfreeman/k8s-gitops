# Dragonfly Component

Reusable Dragonfly component for app-local cache/session storage with certificate or password authentication.

## Usage

```yaml
components:
  - ../../../../components/dragonfly
dependsOn:
  - name: dragonfly-operator
postBuild:
  substitute:
    APP: *app
```

Add one of these components depending on how the app authenticates to Dragonfly:

```yaml
components:
  - ../../../../components/dragonfly/auth
  - ../../../../components/dragonfly/tls
```

### TLS only

For apps that use TLS/mTLS, add the init script in the app container args:

```yaml
args: [". /dragonfly/init.sh && exec ..."]
```

## Variables

| Name | Default | Description |
| ---- | ------- | ----------- |
| `DRAGONFLY_CLIENT_COMMON_NAME`| `${APP}` | Client certificate common name. |
| `DRAGONFLY_CA_SECRET_NAME` | `${APP}-dragonfly-ca` | CA secret name. |
| `DRAGONFLY_TLS_SECRET_NAME` | `${APP}-dragonfly-tls` | Server TLS secret name. |
| `DRAGONFLY_CLIENT_TLS_SECRET_NAME` | `${APP}-dragonfly-client-tls` | Client certificate secret name. |

## Resources

- `Dragonfly` named `${APP}-dragonfly`
- `ExternalSecret` and `Password` generator named `${APP}-dragonfly-secret` (with **auth**)

## Notes

- This component requires `cert-manager` for *TLS/mTLS* certificates.
