# Envoy Gateway OIDC Component

Kustomize component that adds Pocket ID OIDC authentication and group-based authorization to an Envoy Gateway `HTTPRoute` with a `SecurityPolicy`.

The issuer is always `https://auth.${DOMAIN_0}`. Apps can live on any configured root domain by overriding `ENVOY_OIDC_DOMAIN`; Envoy sends the browser to Pocket ID on `${DOMAIN_0}` for identity, then returns to the app host for the callback.

Authorization is based on the `groups` claim from the ID token. Requests are denied by default unless the user belongs to the configured app group or admin group.

## Usage

For the common admin-only case where the app host is `${APP}.${DOMAIN_0}`, only include the component:

```yaml
components:
  - ../../../../components/envoy-oidc
```

For an app hosted on another root domain, set `ENVOY_OIDC_DOMAIN` in the app Flux `Kustomization`:

```yaml
postBuild:
  substitute:
    APP: *app
    ENVOY_OIDC_DOMAIN: ${DOMAIN_1}
```

For an app whose subdomain differs from `APP`, also set `ENVOY_OIDC_SUBDOMAIN`:

```yaml
postBuild:
  substitute:
    APP: *app
    ENVOY_OIDC_SUBDOMAIN: home
```

For an app available to non-admin users, set `ENVOY_OIDC_GROUP`:

```yaml
postBuild:
  substitute:
    APP: *app
    ENVOY_OIDC_GROUP: user
```

## Split Routes

This component creates the `SecurityPolicy` for you and targets only the `HTTPRoute` named `${APP}`. If an app also needs an API, webhook, callback, or health endpoint that must not go through browser OIDC, create a second route with a different name such as `${APP}-api`.

Example app `ks.yaml`:

```yaml
components:
  - ../../../../components/envoy-oidc
postBuild:
  substitute:
    APP: *app
```

Example `app-template` route configuration:

```yaml
route:
  app:
    forceRename: *app
    hostnames: ['${APP}.${DOMAIN_0}']
    parentRefs:
      - name: envoy-internal
        namespace: envoy-gateway
        sectionName: https
  api:
    hostnames: ['${APP}.${DOMAIN_0}']
    parentRefs:
      - name: envoy-internal
        namespace: envoy-gateway
        sectionName: https
    rules:
      - matches:
          - path:
              type: PathPrefix
              value: /api/webhook
```

- Use `forceRename` when multiple routes exist and `route.app` must keep the base app name for policy `targetRefs`.
- Omit `rules` when app-template can infer the default catch-all route.
- Omit `backendRefs` when app-template can infer the single service backend and port.

## Variables

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | Application name. |
| `ENVOY_OIDC_DOMAIN` | `${DOMAIN_0}` | Root domain used by the protected app callback URL. Use `${DOMAIN_1}` or `${DOMAIN_2}` for apps on those domains. |
| `ENVOY_OIDC_SUBDOMAIN` | `${APP}` | Subdomain used by the protected app callback URL. |
| `ENVOY_OIDC_GROUP` | `admin` | Primary Pocket ID group allowed to access the app. |

## Resources

- `SecurityPolicy` named `${APP}-oidc`
- `ExternalSecret` named `envoy-oidc-secret`
