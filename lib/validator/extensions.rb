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
            puts e.backtrace if ENV['VERBOSE_FORMATTER'] == 'true'
            raise e
          end
        end
        nil
      end

      private

      def extensions_paths
        custom_paths = RSpec.configuration.validator_config.custom_extension_paths

        if custom_paths.empty?
          path = default_extension_path
          return [path] if File.directory?(path)
        else
          return custom_paths
        end

        []
      end

      def default_extension_path
        File.join(File.dirname(RSpec.configuration.validator_config.path), 'extensions')
      end
    end
  end
end