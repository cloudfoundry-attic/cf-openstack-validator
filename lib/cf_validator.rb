class CfValidator
  def self.resources
    @resources ||= Validator::Resources.new
  end

  def self.configuration
    @configuration ||= Validator::Configuration.new(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])
  end
end