# Common Component

Shared Flux component helpers for application namespaces and repository-wide defaults.

This component is intentionally split into small wrappers so each workload can opt into the right behavior with one component path, without duplicating the underlying YAML.

### Components

Add one of these components to an app’s `Kustomization`, based on the use case:

| Path | Includes namespace | Generic patches | app-template patches |
| ---- | :--: | :--: | :--: |
| `common` | ✅ | ✅ | ❌ |
| `common/shared` | ❌ | ✅ | ❌ |
| `common/app` | ✅ | ✅ | ✅ |
| `common/app/shared` | ❌ | ✅ | ✅ |

## Usage

### Dedicated Namespace

Use the root component when the application owns its `dedicated` namespace.

For an app workload with its own namespace:

```yaml
components:
  - ../../../../components/common
```

For an app-template workload with its own namespace:

```yaml
components:
  - ../../../../components/common/app
```

### Shared Namespace

Use `shared` when the namespace is created by another Flux `Kustomization`.

For an app workload in a shared namespace:

```yaml
components:
  - ../../../../components/common/shared
```

For an app-template workload in a shared namespace:

```yaml
components:
  - ../../../../../components/common/app/shared
```

## Shared Namespace

Create the shared namespace with a parent `Kustomization` that points to components/common:

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &namespace <namespace-name>
spec:
  dependsOn:
    - name: <example-app>
  interval: 1h
  path: kubernetes/components/common
  prune: false
  sourceRef:
    kind: GitRepository
    name: flux-system
  targetNamespace: *namespace
```

Put shared `dependsOn` entries so child apps do not repeat them in their Kustomization.

## Variables

### Namespace component

| Name | Default | Description |
| ---- | ------- | ----------- |
| `ENVOY_GATEWAY_ACCESS` | `internal` | Namespace label used to mark the default Envoy Gateway access class. |
| `POD_SECURITY_ENFORCE` | `restricted` | Namespace Pod Security admission enforcement level. |

## Resources

### Namespace resources:

- `Namespace` named by the consuming Flux `Kustomization` target namespace.
- Namespace labels for `domain`, `envoy-gateway-access`, and restricted pod security enforcement.

### Generic patches:

- Patches `HelmRelease` resources with retry-on-failure install and upgrade behavior.
- Patches `HelmRelease` resources with `CreateReplace` CRD handling.
- Patches `HelmRelease` resources with cleanup-on-fail rollback and upgrade behavior.
- Patches `ExternalSecret` target templates with `reconcile.fluxcd.io/watch: Enabled`.

### app-template patches:

- Adds a `tmp` `emptyDir` persistence entry to app-template `HelmRelease` resources.

## Notes

- The namespace `domain` label value is injected by the app domain parent `Kustomization`.
- Do not use `common/app` for non app-template charts.
