require_relative '../../lib/validator'

include Validator::Api::Helpers

RSpec.configure do |config|
  config.register_ordering(:openstack) do |items|
    items.sort_by { |item| item.metadata[:position] }
  end

  config.add_setting :validator_config
  config.validator_config = Validator::Api::Configuration.new(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])

  config.add_setting :validator_resources
  config.validator_resources = Validator::Resources.new
end
