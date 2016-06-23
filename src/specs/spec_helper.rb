require_relative 'openstack_spec_helper'

RSpec.configure do |config|

  config.before(:suite) do
    $resources = {
        instances: [],
        images: [],
        volumes: [],
        snapshots: []
    }
  end

  config.after(:suite) do
    leaked_resources = $resources.inject(0) { |sum, entry| sum += entry[1].length }

    if leaked_resources > 0
      puts red "\nThe following resources might not have been cleaned up:\n"
      puts red $resources
                   .reject { |_, resource_ids| resource_ids.length == 0 }
                   .map { |resource_type, resource_ids| "  #{resource_type}: #{resource_ids.join(', ')}" }
                   .join("\n")
    end
  end

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
      @openstack_params = openstack_params
      @fog_params = convert_to_fog_params(@openstack_params)
      @compute = compute(@fog_params)
    end
  end
end