module Validator

  class Extensions
    class << self
      def all
        extensions_paths.map do |path|
          Dir.glob(File.join(path, '*_spec.rb'))
        end.flatten
      end

      def eval(specs, binding)
        specs.each do |file|
          puts "Evaluating extension: #{file}"
          begin
            binding.eval(File.read(file), file)
          rescue Exception => e
            puts e
            puts e.backtrace if RSpec::configuration.options.verbose?
            raise e
          end
        end
        nil
      end

      private

      def extensions_paths
        RSpec.configuration.validator_config.custom_extension_paths
      end
    end
  end
end