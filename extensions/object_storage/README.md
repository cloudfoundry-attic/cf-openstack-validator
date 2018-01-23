# Object Storage Extension

This extension verifies that the Object Storage of your OpenStack can be used by the CloudFoundry Cloud Controller.

## Configuration

Configure a `Temp-url-key` in OpenStack as described [here](https://docs.openstack.org/developer/swift/api/temporary_url_middleware.html#secret-keys).
The 'tempurl' feature also needs to be configured in Swift by an OpenStack administrator.
To avoid conflicts, if you run multiple validator jobs, an optional `validator-dirname` can be set.

Add the extension to your `validator.yml`:

```yaml
extensions:
  paths: [./extensions/object_storage]
  config:
    object_storage:
      openstack:
        openstack_temp_url_key: <temp-url-key>
        openstack_validator_dirname: <validator-dirname>
```
