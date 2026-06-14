---
name: app-template
description: Use when answering questions about the locally vendored bjw-s app-template chart used by this repo: default values, available fields, schema paths, rendered templates, or how to write values blocks in app-template HelmReleases without browsing, pulling the chart, or checking the Flux pin.
---

# App Template Chart Reference

Use this skill for questions about `spec.values` in HelmReleases that use the bjw-s `app-template` chart.

## Source

The chart is vendored locally:

```text
.agents/skills/app-template/chart/app-template
```

Vendored chart:

```text
app-template 5.0.1
common       5.0.1
```

## Fast Path

For read-only questions about defaults, fields, or examples:

- Do not read `.agents/instructions/sorting.md`.
- Do not search all of `kubernetes/apps` unless the user asks for repo examples.
- Do not run `helm pull`.
- Do not check `kubernetes/flux/repositories/oci/app-template.yaml`.
- Search the local chart first.

Useful files:

```text
.agents/skills/app-template/chart/app-template/Chart.yaml
.agents/skills/app-template/chart/app-template/templates/common.yaml
.agents/skills/app-template/chart/app-template/charts/common/values.yaml
.agents/skills/app-template/chart/app-template/charts/common/values.schema.json
.agents/skills/app-template/chart/app-template/charts/common/templates
```

`app-template` is mostly a wrapper around the `common` library chart. For practical values/default questions, start with `charts/common/values.yaml`, then confirm with `charts/common/values.schema.json` only if needed.

## Chart Map

Main values sections in `charts/common/values.yaml`:

```text
global:                    line 4
defaultPodOptionsStrategy: line 27
defaultPodOptions:         line 33
controllers:               line 298
serviceAccount:            line 1797
configMaps:                line 1822
configMapsFromFolder:      line 1853
secrets:                   line 1882
secretsFromFolder:         line 1913
ingress:                   line 1951
route:                     line 2011
service:                   line 2050
serviceMonitor:            line 2148
podMonitor:                line 2190
networkpolicies:           line 2238
persistence:               line 2308
rbac:                      line 2382
rawResources:              line 2448
```

Common focused template paths:

```text
controllers      charts/common/templates/classes/_deployment.tpl
controllers      charts/common/templates/classes/_statefulset.tpl
controllers      charts/common/templates/classes/_daemonset.tpl
controllers      charts/common/templates/classes/_cronjob.tpl
controllers      charts/common/templates/classes/_job.tpl
containers       charts/common/templates/lib/container/_spec.tpl
container image  charts/common/templates/lib/container/fields/_image.tpl
env/envFrom      charts/common/templates/lib/container/fields/_env.tpl
env/envFrom      charts/common/templates/lib/container/fields/_envFrom.tpl
probes           charts/common/templates/lib/container/fields/_probes.tpl
pod options      charts/common/templates/lib/pod/_spec.tpl
pod volumes      charts/common/templates/lib/pod/fields/_volumes.tpl
volume mounts    charts/common/templates/lib/container/fields/_volumeMounts.tpl
persistence      charts/common/templates/classes/_pvc.tpl
persistence      charts/common/templates/lib/pvc
service          charts/common/templates/classes/_service.tpl
service ports    charts/common/templates/lib/service
route            charts/common/templates/classes/_route.tpl
route            charts/common/templates/lib/routes
ingress          charts/common/templates/classes/_ingress.tpl
ingress          charts/common/templates/lib/ingress
configMaps       charts/common/templates/classes/_configmap.tpl
configMaps       charts/common/templates/lib/configMap
secrets          charts/common/templates/classes/_secret.tpl
secrets          charts/common/templates/lib/secret
serviceAccount   charts/common/templates/classes/_serviceAccount.tpl
serviceMonitor   charts/common/templates/classes/_serviceMonitor.tpl
podMonitor       charts/common/templates/classes/_podMonitor.tpl
networkpolicy    charts/common/templates/classes/_networkpolicy.tpl
rawResources     charts/common/templates/classes/_rawResource.tpl
rbac             charts/common/templates/classes/_role.tpl
rbac             charts/common/templates/classes/_rolebinding.tpl
```

## Quick Queries

List top-level values:

```sh
yq '.properties | keys' .agents/skills/app-template/chart/app-template/charts/common/values.schema.json
```

Find where a field is documented:

```sh
rg -n '"<field-name>"|<field-name>:' .agents/skills/app-template/chart/app-template/charts/common
```

Inspect defaults with comments:

```sh
rg -n '<field-name>' .agents/skills/app-template/chart/app-template/charts/common/values.yaml
```

Read a known section by line number:

```sh
sed -n '<start>,<end>p' .agents/skills/app-template/chart/app-template/charts/common/values.yaml
```

## Local Examples

Only when the user asks for repo-specific patterns, search existing HelmReleases:

```sh
rg -n '<field-name>' kubernetes/apps kubernetes/components -g 'helmrelease.yaml'
```

Common examples are under:

```text
kubernetes/apps/*/*/app/helmrelease.yaml
kubernetes/apps/media/torrent/*/app/helmrelease.yaml
kubernetes/components/vpn/gateway/helmrelease.yaml
```

## Repo Rules

- Follow `.agents/instructions/sorting.md` only when writing or editing app-template HelmReleases.
- Prefer current local examples over invented structure.
- Do not guess defaults. Confirm in local `values.yaml`, `values.schema.json`, or templates.
- Do not browse unless the local chart files and local examples are insufficient.
