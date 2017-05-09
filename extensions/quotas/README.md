# Quotas Extensions

This extension verifies that the given quotas exist in a given project.

## Configuration

Create a `quotas.yml` and include each quota you want to check for. Supported are quotas on `compute`, `volume` and `network`:
There are no mandatory configuration options.

```yaml
compute:
  injected_file_content_bytes: 10240
  metadata_items: 128
  server_group_members: 10
  server_groups: 10
  ram: 768000
  floating_ips: 10
  key_pairs: 100
  instances: 120
  security_group_rules: 20
  injected_files: 5
  cores: 300
  fixed_ips: -1
  injected_file_path_bytes: 255
  security_groups: 10

volume:
  snapshots_default: -1
  per_volume_gigabytes: -1
  gigabytes: 1000
  backup_gigabytes: 1000
  volumes_default: -1
  gigabytes_default: -1
  snapshots: 10
  volumes: 200
  backups: 10

network:
  subnet: 10
  firewall_policy: 10
  firewall_rule: 100
  network: 10
  floatingip: 50
  firewall: 10
  graph: -1
  subnetpool: -1
  security_group_rule: 100
  listener: -1
  pool: 10
  l7policy: -1
  security_group: 10
  router: -1
  rbac_policy: 10
  port: 50
  loadbalancer: 10
  healthmonitor: -1
```

Add the extension to your `validator.yml`:

```yaml
extensions:
  paths: ['./extensions/quotas']
  config:
    quotas:
     expected_quotas: 'quotas.yml'
     project_id: <project_id_to_validate>
```
