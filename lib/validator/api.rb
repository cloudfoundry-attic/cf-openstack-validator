require_relative 'api/fog_openstack'
require_relative 'api/resource_tracker'

module Validator
  module Api
    def self.skip_test(message)
      RSpec.current_example.example_group_instance.skip(message)
    end

    # Return a configuration object representing the validator.yml configuration
    #
    # The custom configuration setting `validator_config` is defined when starting the test suite in spec_helper.rb
    def self.configuration
      RSpec::configuration.validator_config
    end

    # Returns a Validator::Resource object containing all ResourceTrackers
    #
    # The `validator_resources` is defined when starting the test suite in spec_helper.rb
    def self.resources
      RSpec::configuration.validator_resources
    end
  end
end