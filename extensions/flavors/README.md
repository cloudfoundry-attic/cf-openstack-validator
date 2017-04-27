# Flavors Extensions

This extension verifies that the given flavors exist in `openstack.project` configured in `validator.yml`.

## Configuration

Create a `flavors.yml` and include each flavor you want to check for:

```yaml
- name: m1.small
    vcpus: 1
    ram: 2048
    disk: 20
    ephemeral: 0
- name: m1.medium
    vcpus: 2
    ram: 4096
    disk: 40
    ephemeral: 0
```

`name`, `vcpus`, `ram`, `disk`, and `ephemeral` are mandatory fields.

You can optionally check for required metadata as well, e.g. hardware number generators

```yaml
- name: m1.small-hw_rng
    vcpus: 1
    ram: 2048
    disk: 20
    ephemeral: 0
    metadata:
      hw_rng:allowed: 'True'
```
The [OpenStack admin guide](https://docs.openstack.org/admin-guide/compute-flavors.html#extra-specs) provides an overview of possible metadata.

Add the extension to your `validator.yml`:

```yaml
extensions:
  paths: ['./extensions/flavors']
  config:
    flavors:
     expected_flavors: 'flavors.yml'
```
