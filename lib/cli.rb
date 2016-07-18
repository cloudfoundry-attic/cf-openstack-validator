class Cli

  def initialize(env)
    @bosh_openstack_validator_skip_cleanup = env['BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP']
  end

  def skip_cleanup?
    !@bosh_openstack_validator_skip_cleanup.nil? && @bosh_openstack_validator_skip_cleanup.upcase == 'TRUE'
  end
end