module Validator
  class CfValidator
    def self.resources
      @resources ||= Validator::Resources.new
    end

    def self.configuration(validator_config_path = ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])
      @configuration ||= Validator::Configuration.new(validator_config_path)
    end
  end
end