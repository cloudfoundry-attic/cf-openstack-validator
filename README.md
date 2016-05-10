# CF OpenStack Validator

* Roadmap: [Pivotal Tracker](https://www.pivotaltracker.com/epic/show/2156200) (click on Add/View Stories)

# Prerequisites

1. Create an OpenStack project/tenant
1. Create a network
1. Create a key pair `cf-validator`
1. Create a security group `cf-validator`

# Usage

* `git clone https://github.com/cloudfoundry-incubator/cf-openstack-validator.git`
* `cd cf-openstack-validator`
* Create file `cpi.json` with the following content and replace occurences of `<replace-me>` with appropriate values (see prerequisites)
```
{
  "cloud": {
    "plugin": "openstack",
    "properties": {
      "openstack": {
        "auth_url": "<replace-me>",
        "username": "<replace-me>",
        "api_key": "<replace-me>",
        "default_key_name": "cf-validator",
        "default_security_groups": [
          "cf-validator"
        ],
        "wait_resource_poll_interval": 5,
        "ignore_server_availability_zone": false,
        "endpoint_type": "publicURL",
        "state_timeout": 300,
        "stemcell_public_visibility": false,
        "connection_options": {
          "ssl_verify_peer": false
        },
        "boot_from_volume": false,
        "use_dhcp": true,
        "domain": "<replace-me>",
        "project": "<replace-me>",
        "human_readable_vm_names": true
      },
      "registry": {
        "endpoint": "http://localhost:11111",
        "user": "fake",
        "password": "fake"
      }
    }
  },
  "validator": {
    "network_id": "<replace-me>"
  }
}
```
* Download OpenStack CPI from [OpenStack CPI bosh.io](http://bosh.io/releases/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release?all=1)
* Download a stemcell from [OpenStack stemcells bosh.io](http://bosh.io/stemcells/bosh-openstack-kvm-ubuntu-trusty-go_agent)
* Start validation 
```
./validate bosh-openstack-cpi-release-<xxx>.tgz bosh-stemcell-<xxx>-openstack-kvm-ubuntu-trusty-go_agent.tgz cpi.json [<working-dir>]
```
