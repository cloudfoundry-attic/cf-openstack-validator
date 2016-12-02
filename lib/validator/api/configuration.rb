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
        Converter.convert(all.fetch('openstack'))
      end

      def extensions
        all.fetch('extensions', {}).fetch('config', {})
      end

      def custom_extension_paths
        return [] unless all
        paths = all.fetch('extensions', {}).fetch('paths', [])
        paths.map do |path|
          resolved_path = if Pathname.new(path).absolute?
            path
          else
            File.expand_path(path, File.dirname(@path))
          end

          raise Validator::Api::ValidatorError, "'#{resolved_path}' is not a directory." unless File.directory?(resolved_path)

          resolved_path
        end
      end
    end
  end
end