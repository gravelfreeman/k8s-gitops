---
name: app-template-update
description: Use when updating the vendored bjw-s app-template chart used by the local app-template skill so it matches the version pinned in kubernetes/flux/repositories/oci/app-template.yaml.
---

# Update Vendored App Template

Use this skill only when updating the vendored chart under:

```text
.agents/skills/app-template/chart/app-template
```

## Workflow

1. Read the pinned version from:

```text
kubernetes/flux/repositories/oci/app-template.yaml
```

2. Replace the vendored chart with that exact version:

```sh
rm -rf .agents/skills/app-template/chart/app-template
mkdir -p .agents/skills/app-template/chart
helm pull oci://ghcr.io/bjw-s-labs/helm/app-template \
  --version "<pinned-version>" \
  --untar \
  --untardir .agents/skills/app-template/chart
```

3. Trim files that are not useful for the main skill:

```text
.agents/skills/app-template/chart/app-template/.helmignore
.agents/skills/app-template/chart/app-template/LICENSE
.agents/skills/app-template/chart/app-template/README.md
.agents/skills/app-template/chart/app-template/Chart.lock
.agents/skills/app-template/chart/app-template/values.yaml
.agents/skills/app-template/chart/app-template/values.schema.json
.agents/skills/app-template/chart/app-template/charts/common/.helmignore
.agents/skills/app-template/chart/app-template/charts/common/LICENSE
.agents/skills/app-template/chart/app-template/charts/common/README.md
```

Keep:

```text
.agents/skills/app-template/chart/app-template/Chart.yaml
.agents/skills/app-template/chart/app-template/templates/common.yaml
.agents/skills/app-template/chart/app-template/charts/common/Chart.yaml
.agents/skills/app-template/chart/app-template/charts/common/values.yaml
.agents/skills/app-template/chart/app-template/charts/common/values.schema.json
.agents/skills/app-template/chart/app-template/charts/common/templates
```

## Rules

- Do not add hand-written summaries or per-topic reference files.
- Do not change the main skill's chart map unless the vendored chart structure actually changed.
- After updating, verify that the vendored `Chart.yaml` version matches the Flux pin.
