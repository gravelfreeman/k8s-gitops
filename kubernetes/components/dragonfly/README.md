# Dragonfly Component

Reusable Dragonfly component for app-local cache/session storage with password authentication.

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

## Variables

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` | required | App name used for resource names and secret generation. |

## Resources

- `Dragonfly` named `${APP}-dragonfly`
- `ExternalSecret` and `Password` generator named `${APP}-dragonfly-secret`

## Notes

- The component mounts `${APP}-dragonfly-secret` at `/dragonfly`.
