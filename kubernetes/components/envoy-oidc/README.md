# Envoy Gateway OIDC Component

Adds Pocket ID OIDC authentication to an Envoy Gateway `HTTPRoute`.

## Usage

For the common admin-only case where the app host is `${APP}.domain.tld`, only include the component:

```yaml
components:
  - ../../../../components/envoy-oidc
```

For an app available to non-admin users:

```yaml
postBuild:
  substitute:
    APP: *app
    ENVOY_OIDC_GROUP: user
```

## Split Routes

This component creates the `SecurityPolicy` for you and targets only the `HTTPRoute` named `${APP}`, unless *overridden*. If an app also needs an **API**, **webhook**, **callback**, or **health** endpoint that must not go through browser OIDC, create a second route with a different name such as `${APP}-api`.

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

## Variables

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | Application name. |
| `ENVOY_OIDC_GROUP` | `admin` | Primary Pocket ID group allowed to access the app. |

## Resources

- `SecurityPolicy` named `${APP}-oidc`
- `ExternalSecret` named `envoy-oidc-secret`

## Notes

- The issuer is always `https://id.${DOMAIN_0}`.
- Authorization is based on the `groups` claim from the ID token.
