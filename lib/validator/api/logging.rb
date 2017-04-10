module Validator
  module Api
    module Logging
      def log_path
        ENV['BOSH_OPENSTACK_CPI_LOG_PATH']
      end
    end
  end
end