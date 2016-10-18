module Validator::Cli
  class ErrorWithLogDetails < StandardError
    attr_reader :log_path

    def initialize(log_path)
      @log_path = log_path
    end
  end
end