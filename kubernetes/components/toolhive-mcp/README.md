# ToolHive MCP Component

Registers an app's MCP server in the shared ToolHive group.

## Usage

```yaml
components:
  - ../../../../components/toolhive-mcp
dependsOn:
  - name: toolhive-operator
postBuild:
  substitute:
    APP: *app
    TOOLHIVE_MCP_PORT: "8086"
```

## Variables

| Name | Default | Description |
| ---- | ------- | ----------- |
| `APP` *(required)* | none | App name and MCP server prefix. |
| `NAMESPACE` | `${APP}` | Namespace containing the MCP server. |
| `TOOLHIVE_MCP_PORT` *(required)* | none | MCP server port. |
| `TOOLHIVE_MCP_GROUP` | `toolhive-mcp` | ToolHive group receiving the MCP server. |

## Resources

- `MCPServerEntry` named `${APP}` in the `toolhive` namespace.

## Notes

- The app's MCP server must be available at the `/mcp` path.
