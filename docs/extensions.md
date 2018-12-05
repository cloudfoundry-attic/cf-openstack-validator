# Extensions
> Note: This feature is available in versions >=1.2.
> Please keep in mind that the extension API is still under heavy development and subject to change!

In case you have custom validations that you need to run against OpenStack you can create extensions to the validator.

## How to Write an Extension

This is a step-by-step guide to implement an extension.

### Create Extensions File

You can configure a directory from which extensions are read. Create a directory `validator_extensions` for example in your home directory and add a `my_extension_spec.rb` file. Extensions are in fact [RSpec](http://rspec.info/) tests. That's why they have to be called `*_spec.rb`. An [example extension](/sample_extensions/dummy_extension_spec.rb) comes with the validator.

Add the path of your `validator_extensions` directory into your `validator.yml` under the `extensions` section. You can also configure multiple paths if you have multiple extensions:
```yaml
extensions:
  paths: [extensions/flavors, /home/my-user/validator-extensions/]
```
Paths are resolved relative to the `validator.yml`.

### Write a Simple Test

Let's get started with a minimal RSpec test:

```ruby
fdescribe 'My extension' do

  it 'is true' do
    expect(true).to be(true)
  end

end
```

**Important:** To ensure that only your test runs during development, we use `fdescribe` instead of `describe.` Set the
cli option `--tag focus` to only run tests focused with the `f` prefix as you can see in the next step. Don't forget
to remove those, before publishing your extension.

### Run Your Test

Let's run your test. Start the validator execution as usual, just with the focus tag.

```bash
$ ./validate --tag focus --stemcell bosh-stemcell-<xxx>-openstack-kvm-ubuntu-xenial-go_agent.tgz --config validator.yml
```

### Access OpenStack in Your Test

We want to ensure that we can create a security group in OpenStack. The validator provides an API that enables us to interact
with OpenStack.

```ruby
fdescribe 'My extension' do

  before(:all) { @compute = Validator::Api::FogOpenStack.compute }

  it 'can create a security group allowing SSH' do
    ssh_security_group = @compute.security_groups.create({ 'name' => 'allow-ssh', 'description' => '' })
    ssh_security_group.security_group_rules.create({
      from_port: '22',
      ip_protocol: 'tcp',
      ip_range: { 'cidr' => '0.0.0.0/0' },
      to_port: '22',
      parent_group_id: ssh_security_group.id
    })

    expect(@compute.security_groups.get(ssh_security_group.id)).to_not be_nil

    ssh_security_group.destroy
  end

end
```

### Automatically Clean up Resources Created by Your Tests

If our test would fail, it would leak resources: Nobody is cleaning up the security group we created. To ensure that resources are cleaned up, even when the test is not completely executed, the validator provides a resource tracking API.

The resource tracking API supports automatic cleanup of OpenStack resources. For debugging, cleanup can be skipped by setting the cli option `--skip-cleanup`.

To use the resource tracking, add a statement as follows:

```ruby
fdescribe 'My extension' do

  include_context "resource tracker"

  before(:all) do
    @compute = Validator::Api::FogOpenStack.compute
  end

  it 'can create a security group allowing SSH' do
    ssh_security_group = nil
    ssh_security_group_id = @resource_tracker.produce(:security_groups, provide_as: :my_security_group_id) do
      ssh_security_group = @compute.security_groups.create({ 'name' => 'allow-ssh', 'description' => '' })
      ssh_security_group.id
    end

    ssh_security_group.security_group_rules.create({
      from_port: '22',
      ip_protocol: 'tcp',
      ip_range: { 'cidr' => '0.0.0.0/0' },
      to_port: '22',
      parent_group_id: ssh_security_group_id
    })

    expect(@compute.security_groups.get(ssh_security_group_id)).to_not be_nil
  end

end
```

If you now run the tests with `--skip-cleanup`, it will not clean up the security group and you will see output similar to:
```
...
Finished in 3.28 seconds (files took 0.27329 seconds to load)
1 example, 0 failures
Resources: The following resources might not have been cleaned up:
  Security groups:
    - Name: allow-ssh
      UUID: 6a400796-32ad-42d7-8124-2e73c27b01e3
      Created by test: Your OpenStack Extensions My extension can create a security group allowing SSH
```

Note that you have to manually clean up the security group in the OpenStack UI or with the OpenStack command line client in this case.

### Share Resources Between Tests

You can consume resources you produced in your test using the resource tracker API in other tests by using the `consumes` call:

```ruby
it 'uses security group' do
  ssh_security_group_id = @resource_tracker.consumes(:my_security_group_id)
  expect(@compute.security_groups.get(ssh_security_group_id)).to_not be_nil
end
```

### Passing Parameters to your Extension

If your extension needs any configuration you can add it to the `validator.yml`. Let's read the port for the security group rule from the configuration:
```yaml
extensions:
  paths: ['path_to/my_extension/']
  config:
    my_extension:
     port: 22
```

The complete hash at `config` can be retrieved from your test by calling `Validator::Api.configuration.extensions`.
> Note that the configuration will be globally available to all running extensions.

```ruby
fdescribe 'My extension' do
  include_context "resource tracker"

  before(:all) do
    @compute = Validator::Api::FogOpenStack.compute
  end

  let(:config) { Validator::Api.configuration.extensions }

  it 'can create a security group allowing SSH' do
    ssh_security_group = nil
    ssh_security_group_id = @resource_tracker.produce(:security_groups, provide_as: :my_security_group_id) do
      ssh_security_group = @compute.security_groups.create({ 'name' => 'allow-ssh', 'description' => '' })
      ssh_security_group.id
    end

    ssh_security_group.security_group_rules.create({
      from_port: config['my_extension']['port'],
      ip_protocol: 'tcp',
      ip_range: { 'cidr' => '0.0.0.0/0' },
      to_port: config['my_extension']['port'],
      parent_group_id: ssh_security_group_id
    })

    expect(@compute.security_groups.get(ssh_security_group_id)).to_not be_nil
  end

end
```

If you need multiple parameters, we recommend to store all of them in one extension-specific configuration file next to your spec files.
Then you just hand in the path to your config file as config parameter into `validator.yml`.

```yaml
security_group_name: 'allow-ssh'
protocol: 'tcp'
port: 22
```

```yaml
extensions:
  paths: ['path_to/my_extension/']
  config:
    my_extension:
     path: 'path_to/my_extension_config.yml'
```

Access your own config parameters by loading the file in your spec:

```ruby
fdescribe 'My extension' do
  include_context "resource tracker"

  before(:all) do
    @compute = Validator::Api::FogOpenStack.compute
  end

  let(:config) { Validator::Api.configuration.extensions }
  let(:my_config) { YAML.load_file(config['my_extension']['path']) }

  it 'can create a security group allowing SSH' do
    ssh_security_group = nil
    ssh_security_group_id = @resource_tracker.produce(:security_groups, provide_as: :my_security_group_id) do
      ssh_security_group = @compute.security_groups.create({ 'name' => my_config['security_group_name'], 'description' => '' })
      ssh_security_group.id
    end

    ssh_security_group.security_group_rules.create({
      from_port: my_config['port'],
      ip_protocol: my_config['protocol'],
      ip_range: { 'cidr' => '0.0.0.0/0' },
      to_port: my_config['port'],
      parent_group_id: ssh_security_group_id
    })

    expect(@compute.security_groups.get(ssh_security_group_id)).to_not be_nil
  end

end
```


### Finishing Up

That's it, you have implemented your first validator extension. As a last step don't forget to remove all `f` prefixes in front
of `describe`, `context` or `it` steps, so that the whole test suite is executed.

If you publish your extension, make sure to include a README that describes all available configuration options.
For an example, have a look at [Flavors Extension](../extensions/flavors/).

## Extension API Details

### Interact with OpenStack

To interact with OpenStack the validator provides access via an API. Currently the API exposes
`compute`/`nova`, `image`/`glance`, `volume`/`cinder` and `network`/`neutron` instances using `Fog`.
`Fog` is a Ruby library that offers bindings for different IaaS platforms, including OpenStack.
To create instances do:

```ruby
# Create a new compute instance
compute = Validator::Api::FogOpenStack.compute
# List all servers
server_collection = compute.servers

# Create a new network instance
network = Validator::Api::FogOpenStack.network
# List all networks
network_collection = network.networks

# Create a new image instance
image = Validator::Api::FogOpenStack.image
# List all images
image_collection = image.images

# Create a new volume instance
volume = Validator::Api::FogOpenStack.volume
# List all volumes
volume_collection = volume.volumes
```

The factory methods create a new instance each time you call them. Be aware that creating an instance, will already
do an authentication call to keystone. For this reason it might be useful to just create one instance in a before hook.

The options used to create those instances are the same that are used in the validator core tests. They are derived from
the `validator.yml` the user provided.

To learn more about the usage of `Fog OpenStack` please have a look at its [documentation](https://github.com/fog/fog-openstack).

### The OpenStack Resource Tracker

The validator offers a central handling of OpenStack resources that are created during test runs. It takes care of
cleaning up all resources at the end of a test run. The user can configure to skip this cleanup for debugging purposes (`--skip-cleanup`).
Any leftover resources are reported at the end of the test run.

To hook into this resource management, every extension can create a [ResourceTracker](../lib/validator/api/resource_tracker.rb).

```ruby
# create a resource tracker instance
resource_tracker = Validator::Api::ResourceTracker.create
```
Such an instance provides `produce` and `consumes` methods to manage resources tied to the resource tracker.
Each resource tracker is responsible for its own set of resources. Checkout the methods documentation [here](/lib/validator/api/resource_tracker.rb).

**Remark**: Only the following collections are supported:

* **compute**: flavors, key_pairs, servers, server_groups
* **network**: networks, ports, subnets, floating_ips, routers, security_groups, security_group_rules
* **image**: images
* **volume**: volumes, snapshots
* **storage**: files, directories

This means one can still use other collections the Fog Api offers, but the resource tracker cannot track and clean them up.
This would then have to be done manually.
