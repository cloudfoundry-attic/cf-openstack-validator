# Options for user-provided extensions of the validation test suite

## Target API:
* We want to provide and use by ourselves: `cli`, `fog`, `cpi`
    * cli: openstack & neutron cli wrapper
    * cpi: cpi wrapper (see below in ToDos)
    * fog: fog (wrapper? advertise at all?)
* `provide` and `consume` to handle resource dependencies
* Tests don't need to reference anything from us, but are `eval`ed in the right
  context. Extensions paths are defined and configured in `validator.yml:extensions`.
  API methods are just available.

## OpenStack CLI

* Prerequisites:
  * Install `openstack` client: `sudo pip install python-openstackclient`
  * Install `neutron` client: sudo pip install python-neutronclient
  * Configuration and credentials are taken from validator.yml
* Implemented example for extensions using the CLI API: `custom_test_with_openstack_cli_spec.rb`
 
### Design considerations for CLI wrapper

* Shell out to the openstack CLI client to run commands on OpenStack (e.g. creating networks, etc.)
* Parse results from JSON (using the `-f json` option of the CLI)
* Provide generic API in tests to call CLI with any parameters. Making use of experience users already have with the CLI.
* Requires OpenStack command line client to be installed, we need to tell users how to install it

## How to Specify API

* Documentation
* Examples
* We can't prevent users to directly use Ruby methods and classes which are available in the test environment, but we need to specify what is supported, wht changes to expect, etc.
* Write unit test which checks the availability of the documented API

## To dos

* Review resource tracking and do it in a consistent way for main and extension tests
* Use API defined for extension in main tests as well
* Config:
    * Encapsulate access to validator.yml in config class (Story)
    * Allow to set array of paths for extensions
    * support params in extensions, which can be declared by user tests and get validated
* Logging:
    * Log command line client calls (Story: general overhaul of logging)
* Openstack API `cpi`, `cli`, `fog`:
    * add automatic resource tracking for each of them (Story: general wrapping with error handling)


