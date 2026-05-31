# Cluster Policies

Cluster-wide admission policies that add shared behavior outside individual app components.

## Domains

Domain labels group related applications so they can be listed, inspected, or reconciled together without putting unrelated apps in the same namespace.

### Purpose

This repo mostly uses one namespace per app for isolation. Domains add a second grouping layer for operational views, while shared namespaces remain available for apps that intentionally belong together, such as `plex`.

### Usage

Update the domain parent `kustomization.yaml` and add the domain label transformer:

```yaml
labels:
  - fields:
      - path: metadata/labels
        create: true
      - group: kustomize.toolkit.fluxcd.io
        version: v1
        kind: Kustomization
        path: spec/postBuild/substitute
        create: true
    pairs:
      domain: <domain>
```

Then place child app `ks.yaml` files under that domain path, for example `kubernetes/apps/media/<app>/ks.yaml`.

### Flow

Domain parent paths like `kubernetes/apps/media` inject `domain: media` into child Flux `Kustomization` substitutions. When `components/common` creates a namespace, that value becomes the namespace `domain` label.

Example layout:

```text
kubernetes/apps
├── core
│   ├── kustomization.yaml        # injects domain: core
│   ├── external-secrets/ks.yaml
│   └── pocket-id/ks.yaml
├── media
│   ├── kustomization.yaml        # injects domain: media
│   ├── plex/ks.yaml              # shared namespace parent
│   ├── plex/plex/ks.yaml         # app in shared namespace
│   └── romm/ks.yaml              # app with dedicated namespace
└── services
    ├── kustomization.yaml        # injects domain: services
    ├── homepage/ks.yaml
    └── immich/ks.yaml
```

Shared namespace apps inherit the label from the parent namespace `Kustomization`. For example, apps under the shared `plex` namespace can still be grouped by `domain=media`.

### Policy

`domain.yaml` copies the namespace `domain` label onto namespaced resources created inside that namespace.

This makes it possible to filter by domain, by shared namespace, or by a single app namespace depending on the task.
