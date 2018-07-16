require_relative '../../lib/validator'
require_relative 'support/resource_tracker'

include Validator::Api::Helpers
include Validator::Api::CpiHelpers

RSpec.configure do |config|
  config.register_ordering(:openstack) do |items|
    items.sort_by { |item| item.metadata[:position] }
  end

  config.add_setting :validator_config
  config.validator_config = Validator::Api::Configuration.new(RSpec::configuration.options.config_path)

  config.add_setting :validator_resources
  config.validator_resources = Validator::Resources.new

  config.after(:all) do
    RSpec::configuration.validator_resources.cleanup unless RSpec::configuration.options.skip_cleanup?
  end
end