# List of executed tests

### Testing the CPI API
* Upload stemcell
* Create VM
* Find VM
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
* Can a floating IP be attached?
* Is `ssh` access possible?

### Further reading:
* [Specification of the CPI API v1](http://bosh.io/docs/cpi-api-v1.html)
* [Detailed list of OpenStack API calls of the OpenStack CPI](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release/blob/master/docs/openstack-api-calls.md)
