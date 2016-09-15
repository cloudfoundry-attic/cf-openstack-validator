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

## Custom Validations
> Note: This feature is available in versions >=1.2

In case you have custom validations that you need to run against OpenStack you can always extend the validator.

A custom validation is an RSpec file (*_spec.rb). You can find an [example here](extensions/dummy_extension_spec.sample.rb)

There are two ways to include your custom validations:

1. Add it to `./extensions`
2. Specify the paths to the directories containing your RSpec files in the `validator.yml`
```yml
extensions:
  paths: [my/relative/extension/path, /some/absolute/extension/path]
```

If your custom validation needs any configuration you can pass add it to the `validator.yml`.
```yml
extensions:
  config:
    key: value
```
The complete hash at `config` can be retrieved from your test by calling `CfValidator.configuration.extensions`.
> Note that the configuration will be globally available to all running custom validations.

### Interact with OpenStack

To interact with OpenStack the Validator provides access to `Fog` instances via an API. Currently the API exposes
`compute`/`nova` and `network`/`neutron`. `Fog` is a ruby library that offers bindings for different IaaS platforms,
including OpenStack. To create instances do:

```ruby
# Create a new compute instance
compute = Validator::Api::FogOpenStack.compute
server_collection = compute.servers

# Create a new network instance
network = Validator::Api::FogOpenStack.network
network_collection = network.networks
```

The factory methods create a new instance each time you call them. Be aware that creating an instance, will already
do an authentication call to keystone. For this reason it might be useful to just create on instance in a before hook.

The options used to create those instances are the same that are used in the Valditor core tests. They are derived from 
the `validator.yml` the user provided.

To learn more about the usage of `Fog OpenStack` please have a look at its [documentation](https://github.com/fog/fog-openstack).

### Track OpenStack Resources

The Validator offers a central handling of OpenStack resources that are created during test runs. It takes care of
cleaning up all resources at the end of a test run. The user can configure to skip this cleanup for debugging purposes (see environment variables below).
Any leftover resources are reported at the end of the test run.

To hook into this resource management, every custom validation can create a [ResourceTracker](lib/validator/api/resource_tracker.rb).

```ruby
# create a resource tracker instance
resources = Validator::Api::ResourceTracker.create
```
Such an instance provides `produce` and `consume` methods to manage resources tied to the resource tracker.
Each resource tracker is responsible for its own set of resources. Checkout the methods documentation [here](lib/validator/api/resource_tracker.rb).

**Remark**: Only the following collections are supported:

* **compute**: addresses, flavors, key_pairs, servers, volumes, images, snapshots
* **network**: networks, ports, subnets, floating_ips, routers, security_groups, security_group_rules

This means one can still use other collections the Fog Api offers, but the resource tracker cannot track and clean them up.
This would then have to be done manually.

```ruby
# ...

before(:all) do
  @resources = Validator::Api::ResourceTracker.create
end

it 'creates a resource' do
  server_id = @resources.produce(:servers, provide_as: :my_server_id) {
      # create server in openstack and return the cid
      server_id
  }
end

it 'consumes a resource' do
  server_id = @resources.consume(:my_server_id)
end

# ...
```

# Troubleshooting
The validator doesn't run on your OpenStack? See [additional OpenStack related configuration options](docs/openstack_configurations.md) for possible solutions.

### Environment variables
* **FAIL_FAST**: In general, all tests are executed even if some of them fail. In order to stop after the first test failure, specify `FAIL_FAST=true`.
* **VERBOSE_FORMATTER**: If you are interested in more output for the failing tests, you can set `VERBOSE_FORMATTER=true`.
* **BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP**: Set this variable to `true` to skip cleanup of OpenStack resources. This can be useful for debugging failing tests.
* **TAG**: Use this variable to run examples that match a specified tag. (If you are working with fit, fcontext and fdescribe, use TAG=focus)
