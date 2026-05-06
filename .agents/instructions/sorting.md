# Sorting instructions for YAML files

Whenever asked to sort YAML files, follow these instructions:

- **Default rule**: sort fields alphabetically at every level, unless an override below applies.

## Kubernetes resources

- Top-level Kubernetes resource fields should be sorted as follows:
  - `apiVersion`
  - `kind`
  - `metadata`
  - `spec`

- `metadata` fields should be sorted as follows:
  - `name`
  - `namespace`
  - `annotations`
  - `labels`

## ExternalSecrets

- In `ExternalSecret.spec`, keep fields in this order:
  - `secretStoreRef`
  - `target`
  - `dataFrom`
  - `data`

## HelmReleases based on app-template

This section applies to HelmReleases using the bjw-s `app-template` chart. These can be identified by either:

- `spec.chartRef.name: app-template`
- `spec.chart.spec.chart: app-template`

The shared `app-template` OCIRepository is defined in `kubernetes/flux/repositories/oci/app-template.yaml`.

### Sorting rules

- Whenever there is an `enabled` field, it should be first in its section.

- `HelmRelease.spec` fields should be sorted as follows:
  - `interval`
  - `chartRef`
  - `chart`
  - `dependsOn`
  - `install`
  - `upgrade`
  - `values`

- `spec.values` fields should be sorted as follows:
  - `defaultPodOptions`
  - `defaultContainerOptions`
  - All other sibling keys alphabetically, e.g. `controllers`, `persistence`, `route`, `service`, `serviceAccount`

- Do not sort sibling items inside sections such as `controllers`, `persistence`, `route`, `service`, `configMaps`, or `secrets`; only sort fields within each item.

- Do not sort arbitrary YAML embedded inside string fields.

### Detailed sorting rules for nested sections

- Items within the `spec.values.controllers.*` sections should be sorted as follows:
  - `type` (if present, always first)
  - `annotations` (if present)
  - `labels` (if present)
  - Controller-specific fields such as `cronjob` or `statefulset` (if present)
  - `pod`
  - Any other fields should be sorted alphabetically, except the following fields which should come last (and in this order):
  - `initContainers` (if present)
  - `containers` (if present)

- Items within `spec.values.controllers.*.containers.*` sections should be sorted as follows:
  - `image`
  - Any other fields should be added next in alphabetical order.

- Items within `spec.values.controllers.*.containers.resources` and `spec.values.controllers.*.initContainers.resources` sections should be sorted as follows:
  - `requests`
  - `limits`

- Items within `spec.values.service.*` sections should be sorted as follows:
  - `type` (if present)
  - `annotations` (if present)
  - `labels` (if present)
  - Any other fields should be added next in alphabetical order.

- Items within `persistence.*` sections should be sorted as follows:
  - `type` (if present)
  - `annotations` (if present)
  - `labels` (if present)
  - Any other fields should be sorted alphabetically, except the following fields which should come last (and in this order):
  - `globalMounts` (if present)
  - `advancedMounts` (if present)
