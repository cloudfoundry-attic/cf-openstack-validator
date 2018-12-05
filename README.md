# CF OpenStack Validator

Is your OpenStack installation ready to run BOSH and install Cloud Foundry? Run this validator to find out.

* Roadmap: [Pivotal Tracker](https://www.pivotaltracker.com/epic/show/2156200) (click on Add/View Stories)
* Slack: `#openstack` on cloudfoundry.slack.com ([get your invite here](https://slack.cloudfoundry.org/))
* [List of executed tests](docs/list_of_executed_tests.md)

## Prerequisites

### OpenStack

* Keystone v2/v3
* Create an OpenStack project/tenant
* Create a user with access to the previously created project/tenant (ideally you don't want to run as admin)
* Create a network
  * Connect the network with a router to your external network
* Allocate a floating IP
* Allow ssh access in the `default` security group
* Create a key pair by executing
```bash
$ ssh-keygen -t rsa -b 4096 -N "" -f cf-validator.rsa_id
```
  * Upload the generated public key to OpenStack as `cf-validator`

* A public image available in glance
  * If your OpenStack installation doesn't yet provide any image, you can upload a [CirrOS test image](http://docs.openstack.org/image-guide/obtain-images.html#cirros-test)

### Environment

The validator runs on Mac and Linux. Please ensure that the following packages are installed on your system:

**Linux Requirements**

* ruby 2.4.x or newer
* make
* gcc
* zlib1g-dev
* libssl-dev
* ssh

**Mac Requirements**

* xcode command line tools

**Running the validator**

The intended place to run the validator is a VM within your OpenStack. If you are executing the tests from a machine outside your OpenStack, you need to set `validator.use_external_ip` to `true`.

## Usage

* `git clone https://github.com/cloudfoundry-incubator/cf-openstack-validator.git`
* `cd cf-openstack-validator`
* Copy the generated private key into the `cf-openstack-validator` folder.
* Copy [validator.template.yml](validator.template.yml) to `validator.yml` and replace occurrences of `<replace-me>` with appropriate values (see prerequisites)
  * If using Keystone v3, ensure there are values for `domain` and `project`
  * If using Keystone v2, remove `domain` and `project`, and ensure there is a value for `tenant`. Also use the Keystone v2 URL as `auth_url`.
```bash
$ cp validator.template.yml validator.yml
```
* Download a stemcell from [OpenStack stemcells bosh.io](https://bosh.io/stemcells/bosh-openstack-kvm-ubuntu-xenial-go_agent)
```
$ wget --content-disposition https://bosh.io/d/stemcells/bosh-openstack-kvm-ubuntu-xenial-go_agent
```
* Install dependencies
```bash
$ gem install bundler
$ bundle install
```
* Start validation
```bash
$ ./validate --stemcell bosh-stemcell-<xxx>-openstack-kvm-ubuntu-xenial-go_agent.tgz --config validator.yml
```

## Configure CPI used by validator

Validator downloads CPI release from the URL specified in the validator configuration. You can override this by specifying the `--cpi-release` command line option with the path to a CPI release tarball.

If you already have a CPI compiled, you can specify the path to the executable in the environment variable `OPENSTACK_CPI_BIN`. This is used when no CPI release is specified on the command line. It overrides the setting in the validator configuration file.

## Command line help

To learn about available options run
```bash
$ ./validate --help
```

## Extensions

You can extend the validator with custom tests. For a detailed description and examples, please have a look at the [extension documentation](./docs/extensions.md).

This repository already contains some [extensions](./extensions). Each extension has its own documentation which can be found in the corresponding extension folder.

## Troubleshooting
The validator does not run on your OpenStack? See [additional OpenStack related configuration options](docs/openstack_configurations.md) for possible solutions.
