# Additional OpenStack related configuration options

Depending on you OpenStack configuration, you might need additional configuration options for the validator to run. Note that all of these settings need to be done similarly for BOSH once you deploy a Director or Cloud Foundry.

## Using self-signed certificates

You can add your certificate chain in the property `openstack.connection_options.ca_cert`. Read more on the topic at [bosh.io](http://bosh.io/docs/openstack-self-signed-endpoints.html).

## Using boot disks from block storage instead of hypervisor-local storage

By default, hypervisor-local storage is used for a VMs boot disk. If your OpenStack setup requires you to use disks from block storage instead, you can set `openstack.boot_from_volume: true`.

## Using custom ephemeral disk size

By default, the root disk size and ephemeral disk size of the OpenStack flavor determine the ephemeral disk size available on a BOSH stemcell. If you want to specify your disk size independent of the flavor's disk sizes, you need to enable `openstack.boot_from_volume: true` as described above and configure a different root disk size in `cloud_config.vm_types.['default'].cloud_properties.root_disk.size`. We recommend a minimum size of 10GB.
You can calculate the available ephemeral disk size as `root_disk.size - 3GB - flavor_RAM`.

## Using flavors with 0 root disk size

See above.

## Using internal ntp servers

By default, the validator uses an external ntp server from pool.ntp.org. If your OpenStack installation cannot access external ntp servers, e.g. firewall restrictions, you need to specify an internal ntp server in the property `validator.ntp`. Working time synchronization is necessary for many security concepts, such as token expiration time.

## Using config-drive instead of metadata service

By default, the VMs created try to receive data from OpenStack's HTTP metadata service. If your OpenStack installation doesn't provide medata and userdata over HTTP, but requires you to a config-drive instead, you need to specify this in the property `openstack.config_drive: cdrom`

## Using nova-networking

By default, the OpenStack uses neutron for networking since version 28. If you require nova-networking, switch on `openstack.use_nova_networking: true` to turn on compatibility mode in the CPI. Be aware that future OpenStack versions will remove this API at some point. See [documentation on bosh.io](http://bosh.io/docs/openstack-nova-networking.html) for additional information.

## Using a non-default region

By default, OpenStack uses one default region. If you are using a different one, you can add it in the property `openstack.region`.
