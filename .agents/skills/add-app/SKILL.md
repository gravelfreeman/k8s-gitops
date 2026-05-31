---
name: add-app
description: Scaffold or update an app-template application in this Talos/Kubernetes/Flux GitOps cluster, following the local one-namespace-per-app, shared app-template, External Secrets, and shared component patterns.
---

# Add New Application

This skill scaffolds a new application in in this cluster based on the `app-template` Helm chart.

## Workflow

### Step 1: Collect Application Details

Gather only the details that cannot be inferred from docs or local examples:

1. **App name** - Kubernetes resource name and namespace name, e.g. `romm`
2. **Domain** - top-level app group, `core`, `media`, `services`, `system` and `utils`
3. **Image repository** - full container image URL (e.g., `ghcr.io/autobrr/autobrr`)
4. **Image tag** - version tag (e.g., `v1.76.0`)
5. **Port** - application port number (e.g., `7474`)
6. **Ingress host** - host under `${DOMAIN_0}` or `${DOMAIN_1}` or `${DOMAIN_2}`
7. **Persistence** - whether the app needs a single backed-up PVC named `data`
8. **Dependencies** - any Flux Kustomization dependencies (e.g., `rook-ceph-cluster`)
9. **Has secrets** - whether to create an ExternalSecret (yes/no)

### Step 2: Create Directory Structure

Create the directory:

```text
kubernetes/apps/<domain>/<app-name>/app/
```

Use one Kubernetes namespace per app. For app-template workloads, create the app namespace through `components/common/app`.

### Step 3: Generate Files

Create these files with templated values, adapting to the application's needs.

---

**`kubernetes/apps/<domain>/<app-name>/ks.yaml`**

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app <app-name>
spec:
  commonMetadata:
    labels:
      app.kubernetes.io/name: *app
  components:
    - ../../../../components/common/app
    # - ../../../../components/cnpg
    # - ../../../../components/dragonfly
    # - ../../../../components/dragonfly/tls
    # - ../../../../components/envoy-oidc
    # - ../../../../components/volsync
    # - ../../../../components/vpn
 # dependsOn:
    # - name: cloudnative-pg
    # - name: dragonfly-operator
    # - name: onepassword
    # - name: volsync
  interval: 1h
  path: kubernetes/apps/<domain>/<app-name>/app
  postBuild:
    substitute:
      APP: *app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  targetNamespace: *app
  timeout: 5m
```

- Keep `dependsOn` minimal and app-level; avoid bootstrap/platform dependencies and transitive duplicates.
- Do not set *component* defaults explicitly; override only when the app requires a different non-sensitive value.
- Prefer `components/dragonfly/tls`; use `components/dragonfly/auth` only when the app cannot use TLS or mTLS.

---

**`kubernetes/apps/<domain>/<app-name>/app/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - externalsecret.yaml
  - helmrelease.yaml
```

- Use `configMapGenerator` only for static config files.
- Include `./externalsecret.yaml` only if secrets are needed.

---

**`kubernetes/apps/<domain>/<app-name>/app/helmrelease.yaml`**

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/helm.toolkit.fluxcd.io/helmrelease_v2.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: <app-name>
spec:
  interval: 30m
  chartRef:
    kind: OCIRepository
    name: app-template
    namespace: flux-system
  values:
    controllers:
      <app-name>:
        containers:
          app:
            image:
              repository: <image-repository>
              tag: <vX.X.X>@sha256:<digest>
            probes:
              liveness: &probes
                enabled: true
                type: HTTP
                path: /health
              readiness: *probes
            resources:
              requests:
                cpu: 25m
                memory: 128Mi
            securityContext:
              readOnlyRootFilesystem: true
              allowPrivilegeEscalation: false
              capabilities:
                drop: ["ALL"]
        pod:
          securityContext:
            runAsNonRoot: true
            runAsUser: 568
            runAsGroup: 568
            fsGroup: 568
            fsGroupChangePolicy: OnRootMismatch
            seccompProfile:
              type: RuntimeDefault
          automountServiceAccountToken: false
    persistence:
      data:
        existingClaim: <app-name>-data
    service:
      app:
        ports:
          http:
            port: <service-port>
```

- Run apps as *non-root* UID/GID `568` by default.
- Do not set `TZ`; timezone injection is handled by default by *k8tz*.
- Check the application's official recommendations before setting requests/limits.
- Use one backed-up PVC named `data`; mount multiple persistent paths with `subPath` or `advancedMounts`.
- Use *NFS* for shared media/library data.

If there's more than one container, set shared pod/container-level defaults instead:

```yaml
spec:
  values:
    controllers:
      <app-name>:
        defaultContainerOptions:
          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
    defaultPodOptions:
      securityContext:
        runAsNonRoot: true
        runAsUser: 568
        runAsGroup: 568
        fsGroup: 568
        fsGroupChangePolicy: OnRootMismatch
        seccompProfile:
          type: RuntimeDefault
      automountServiceAccountToken: false
```

---

**`kubernetes/apps/<domain>/<app-name>/app/externalsecret.yaml`** (only if needed)

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: &secret <app-name>-app-secret
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: *secret
  dataFrom:
    - extract:
        key: <app-name>
```

- Prefer `dataFrom.extract` for the app's own *1Password* item.
- Use explicit `data` entries for shared or cross-app secrets.
- Non-sensitive *common* values are provided through *Flux* `postBuild` substitutions.

### Step 4: Update Domain Kustomization

Read `kubernetes/apps/<domain>/kustomization.yaml` and add the new app's `ks.yaml` to the resources array:

```yaml
resources:
  - <app-name>/ks.yaml
```

### Step 5: Verify

Run targeted, non-destructive checks:

```bash
find kubernetes/apps/<domain>/<app-name> -type f | sort
kustomize build kubernetes/apps/<domain>/<app-name>/app
```

## Notes

- Use *YAML anchors* where they improve clarity and reduce repeated values.
- Remove all scaffold-only comments before finalizing generated manifests.
