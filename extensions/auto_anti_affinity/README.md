# Auto-Anti-Affinity Extension

This extension verifies that your OpenStack supports soft-anti-affinity policy for server groups.

## Configuration

You need to specify the ID of the project you run the validator against.

Add the extension to your `validator.yml`:

```yaml
extensions:
  paths: [./extensions/auto_anti_affinity]
  config:
    auto_anti_affinity:
      project_id: <project_id>
```
