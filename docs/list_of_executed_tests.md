# List of executed tests

### Testing the CPI API
* Upload stemcell
* Create VM
* Find VM
* Set VM metadata tags
* Create disk
* Find disk
* Attach disk to VM
* Detach disk from VM
* Create disk snapshot
* Delete disk snapshot
* Delete disk
* Delete VM
* Delete stemcell

### Other OpenStack tests
* Check API rate limit
* Check required versions of OpenStack projects
  * CPI requires API version 1 for glance and cinder
* Security group settings
  * Check if security group rules allow necessary incoming/outgoing ports
* Outbound internet access from a VM
* Store and retrieve user-data
  * from the HTTP metadata service
  * from config-drive
* Attach a floating IP
* Access a VM over ssh from the outside
* Timeservers can be reached
* Static networking is possible
* Access one VM from another VM
* Create a large volume

### Further reading:
* [Specification of the CPI API v1](http://bosh.io/docs/cpi-api-v1.html)
* [Detailed list of OpenStack API calls of the OpenStack CPI](https://github.com/cloudfoundry/bosh-openstack-cpi-release/blob/master/docs/openstack-api-calls.md)
