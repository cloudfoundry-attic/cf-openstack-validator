module Validator::Cli
  class ErrorWithLogDetails < StandardError
    attr_reader :log_path

    def initialize(log_path, error_message)
      @log_path = log_path
      @error_message = error_message
    end

    def message
      "Error: #{@error_message}\n\nMore details can be found in #{@log_path}\n"
    end
  end
end