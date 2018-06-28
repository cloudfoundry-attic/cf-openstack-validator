# Object Storage Extension

This extension verifies that the Object Storage of your OpenStack can be used by the CloudFoundry Cloud Controller.

## Configuration

Configure a `Temp-url-key` in OpenStack as described [here](https://docs.openstack.org/swift/latest/api/temporary_url_middleware.html#secret-keys).
The 'tempurl' feature also needs to be configured in Swift by an OpenStack administrator.

Add the extension to your `validator.yml`:

```yaml
extensions:
  paths: [./extensions/object_storage]
  config:
    object_storage:
      openstack:
        wait_for_swift: 5
        openstack_temp_url_key: <temp-url-key>
```
