require_relative 'api/fog_openstack'
require_relative 'api/cpi_helpers'
require_relative 'api/resource_tracker'
require_relative 'api/helpers'
require_relative 'api/configuration'
require_relative 'api/validator_error'

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
  end
end