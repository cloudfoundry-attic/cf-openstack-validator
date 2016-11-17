module Validator
  module Api
    class Configuration
      def initialize(path)
        @path = path
      end

      def all
        @configuration ||= begin
          YAML.load_file(@path)
        end
      end

      def openstack
        Converter.convert(all.fetch('openstack'))
      end

      def extensions
        all.fetch('extensions', {}).fetch('config', {})
      end
    end
  end
end