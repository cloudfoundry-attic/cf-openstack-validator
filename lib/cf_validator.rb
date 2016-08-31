class CfValidator
  def self.resources
    @resources ||= ResourceTracker.new
  end

  def self.configuration
    @configuration ||= Validator::Configuration.new(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])
  end
end