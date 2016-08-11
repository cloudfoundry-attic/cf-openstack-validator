# CF OpenStack Validator

Is your OpenStack installation ready to run BOSH and install Cloud Foundry? Run this validator to find out.

* Roadmap: [Pivotal Tracker](https://www.pivotaltracker.com/epic/show/2156200) (click on Add/View Stories)
* [List of executed tests](docs/list_of_executed_tests.md)

# Prerequisites

### OpenStack

* Keystone v3
* Create an OpenStack project/tenant
* Create a network
  * Connect the network with a router to your external network
* Allocate a floating IP
* Allow ssh access in the `default` security group
* Create a key pair by executing
```bash
$ ssh-keygen -t rsa -b 4096 -N "" -f cf-validator.rsa_id
```
  * Upload the generated public key to OpenStack as `cf-validator`

### Environment

The validator runs on Mac and Linux.
Please ensure that the following list is installed on the Linux system
where the validator is executed:

* make
* gcc
* zlib1g-dev
* libssl-dev
* ssh

To run on Mac the `Xcode` command line tools have to be installed.

# Usage

* `git clone https://github.com/cloudfoundry-incubator/cf-openstack-validator.git`
* `cd cf-openstack-validator`
* Copy the generated private key into the `cf-openstack-validator` folder.
* Copy [validator.template.yml](validator.template.yml) to `validator.yml` and replace occurrences of `<replace-me>` with appropriate values (see prerequisites)
```bash
$ cp validator.template.yml validator.yml
```
* Download OpenStack CPI from [OpenStack CPI bosh.io](http://bosh.io/releases/github.com/cloudfoundry-incubator/bosh-openstack-cpi-release?all=1)
* Download a stemcell from [OpenStack stemcells bosh.io](http://bosh.io/stemcells/bosh-openstack-kvm-ubuntu-trusty-go_agent)
* Start validation
```bash
$ ./validate bosh-openstack-cpi-release-<xxx>.tgz bosh-stemcell-<xxx>-openstack-kvm-ubuntu-trusty-go_agent.tgz validator.yml [<working-dir>]
```
# Troubleshooting
the validator doesn't run on your OpenStack? See [additional OpenStack related configuration options](docs/openstack_configurations.md) for possible solutions.

### Environment variables
* **FAIL_FAST**: In general, all tests are executed even if some of them fail. In order to stop after the first test failure, specify `FAIL_FAST=true`.
* **VERBOSE_FORMATTER**: If you are interested in more output for the failing tests, you can set `VERBOSE_FORMATTER=true`.
* **BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP**: Set this variable to skip cleanup of OpenStack resources. This can be useful for debugging failing tests.
* **TAG**: Use this variable to run examples that match a specified tag. (If you are working with fit, fcontext and fdescribe, use TAG=focus)
