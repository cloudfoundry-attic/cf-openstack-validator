module Validator
  module Api
    def self.skip_test(message)
      RSpec.current_example.example_group_instance.skip(message)
    end
  end
end