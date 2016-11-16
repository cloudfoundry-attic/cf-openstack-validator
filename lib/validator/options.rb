module Validator
  class Options
    def initialize(env)
      @bosh_openstack_validator_skip_cleanup = env['BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP']
      @verbose_formatter = env['VERBOSE_FORMATTER']
    end

    def skip_cleanup?
      is_true?(@bosh_openstack_validator_skip_cleanup)
    end

    def verbose_output?
      is_true?(@verbose_formatter)
    end

    private

    def is_true?(env_var)
      !env_var.nil? && env_var.upcase == 'TRUE'
    end
  end
end
