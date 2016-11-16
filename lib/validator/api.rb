require_relative 'api/fog_openstack'
require_relative 'api/resource_tracker'

module Validator
  module Api
    def self.skip_test(message)
      RSpec.current_example.example_group_instance.skip(message)
    end
  end
end