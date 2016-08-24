require_relative '../../lib/validator'

RSpec.configure do |config|
  config.register_ordering(:openstack) do |items|
    items.sort_by { |item| item.metadata[:position] }
  end
end

def red(string)
  "\e[31m#{string}\e[0m"
end

def create_vm
  vm = compute(@fog_params).servers.create(server_params)
  wait_for_vm(vm)
  vm
end

def server_params
  image_id = validator_options['public_image_id']
  flavor_name = default_vm_type_cloud_properties['instance_type']
  flavor = compute(@fog_params).flavors.find { |f| f.name == flavor_name }
  server_params = {
      :name => 'validator-test-vm',
      :image_ref => image_id,
      :flavor_ref => flavor.id,
      :config_drive => openstack_params['config_drive'],
      :nics =>[{'net_id' => validator_options['network_id']}]
  }

  if openstack_params['boot_from_volume']
    server_params[:block_device_mapping_v2] = [{
                                                   :uuid => image_id,
                                                   :source_type => 'image',
                                                   :destination_type => 'volume',
                                                   :volume_size => 3,
                                                   :boot_index => '0',
                                                   :delete_on_termination => '1'
                                               }]
    server_params.delete(:image_ref)
  end
  server_params
end

def wait_for_vm(vm)
  state = nil
  while state != 'ACTIVE' do
    vm.reload
    state = vm.state
    if state == 'ERROR' || state == 'FAILED' || state == 'KILLED'
      fail("Failed to start server. It is in state: #{state}")
    end
  end
end

def openstack_suite
  return @openstack_suite if @openstack_suite
  @openstack_suite = RSpec.describe 'Your OpenStack', order: :openstack do

    before(:all) do
      @fog_params = convert_to_fog_params(openstack_params)
      @compute = compute(@fog_params)
    end

    after(:all) do
      CfValidator.resources.untrack(@compute, cleanup: !Cli.new(ENV).skip_cleanup?)
    end

  end
end

def default_vm_type_cloud_properties
  cloud_config['vm_types'][0]['cloud_properties']
end

def private_key_path
  private_key_path = validator_options['private_key_path']
  # TODO is that a relative path?
  File.join(File.dirname(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG']), private_key_path)
end

def validator_options
  @validator_options ||= YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['validator']
end

def cloud_config
  @cloud_config ||= YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['cloud_config']
end