module Validator
  module Api
    class Configuration

      attr_reader :path

      def initialize(path)
        @path = path
      end

      def all
        @configuration ||= begin
          YAML.load_file(@path)
        end
      end

      def validator
        all.fetch('validator')
      end

      def openstack
        Converter.convert_and_apply_defaults(all.fetch('openstack'))
      end

      def cloud_config
        all.fetch('cloud_config')
      end

      def default_vm_type_cloud_properties
        cloud_config['vm_types'][0]['cloud_properties']
      end

      def extensions
        all.fetch('extensions', {}).fetch('config', {})
      end

      def custom_extension_paths
        all
          .fetch('extensions', {})
          .fetch('paths', [])
          .map { |path| File.expand_path(path, File.dirname(@path)) }
      end

      def validate_extension_paths
        custom_extension_paths.each do |path|
          raise Validator::Api::ValidatorError, "Extension path '#{path}' is not a directory." unless File.directory?(path)
        end
      end

      def private_key_path
        File.expand_path(validator['private_key_path'], File.dirname(@path))
      end
    end
  end
end
