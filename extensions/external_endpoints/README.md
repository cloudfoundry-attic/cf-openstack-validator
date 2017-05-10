# External Endpoints Extension

This extension verifies that the given endpoints are reachable.

## Configuration

Create an `endpoints.yml` and include each endpoint you want to check for.

```yaml
- host: github.com
  port: 80

- host: bosh.io
  port: 80
```

Add the extension to your `validator.yml`:

```yaml
extensions:
  paths: ['./extensions/external_endpoints']
  config:
    external_endpoints:
      expected_endpoints: 'endpoints.yml'
```
