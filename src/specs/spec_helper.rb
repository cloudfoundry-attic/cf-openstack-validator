require_relative 'openstack_spec_helper'
require_relative '../../lib/validator'

RSpec.configure do |config|
  config.register_ordering(:openstack) do |items|
    items.sort_by { |item| item.metadata[:position] }
  end
end

def red(string)
  "\e[31m#{string}\e[0m"
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

def cloud_config
  @cloud_config ||= YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['cloud_config']
end