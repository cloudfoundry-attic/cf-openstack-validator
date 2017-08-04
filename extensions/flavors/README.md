# Flavors Extensions

This extension verifies that the given flavors exist in `openstack.project` configured in `validator.yml`.

## Configuration

Create a `flavors.yml` which describes each flavor you want to check in OpenStack. You can describe a flavor using with the following key/value pairs:

| key | value | mandatory |
| ----- |------|-----------|
| name | string | yes |
| vcpus | integer | yes |
| ram | integer [MiB] | yes |
| ephemeral | integer [GiB] | yes |
| metadata | key/value pairs | no |

Each value is evaluated one to one against the flavor in OpenStack, except for `ephemeral` which is evaluated in one of the following ways:

- If the flavor only has Root Disk:

    > Root Disk >= 3 [GiB] + `ephemeral` [GiB] + `ram` [GiB]
    
- If the flavor has Root Disk and Ephemeral Disk:

    > Root Disk >= 3 and Ephemeral Disk >= `ephemeral` [GiB] + `ram` [GiB]
    
The [OpenStack admin guide](https://docs.openstack.org/admin-guide/compute-flavors.html#extra-specs) provides an overview of possible metadata.

Once all flavors are defined, configure the extension in the `validator.yml`:

```yaml
extensions:
  paths: [./extensions/flavors]
  config:
    flavors:
     expected_flavors: </absolute/path/to/flavors.yml>
```

## Examples

```yaml
- name: m1.small
    vcpus: 1
    ram: 2048
    ephemeral: 0
- name: m1.medium
    vcpus: 2
    ram: 4096
    ephemeral: 0
    metadata:
      hw_rng:allowed: 'True'
```
