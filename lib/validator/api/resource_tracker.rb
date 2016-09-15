module Validator
  module Api
    class ResourceTracker
      RESOURCE_SERVICES = {
          compute: [:addresses, :flavors, :key_pairs, :servers, :volumes, :images, :snapshots],
          network: [:networks, :ports, :subnets, :floating_ips, :routers, :security_groups, :security_group_rules]
      }

      def self.create
        CfValidator.resources.new_tracker
      end

      def initialize
        @resources = []
      end

      def count
        resources.length
      end

      def produce(type, provide_as: nil)
        fog_service = service(type)

        unless fog_service
          raise ArgumentError, "Invalid resource type '#{type}', use #{ResourceTracker.resource_types.join(', ')}"
        end


        if block_given?
          resource_id = yield
          resource_name = get_resource(type, resource_id).name
          @resources << {
              type: type,
              id: resource_id,
              provide_as: provide_as,
              name: resource_name,
              test_description: RSpec.current_example.description
          }
          resource_id
        end
      end

      def consumes(name, message = "Required resource '#{name}' does not exist.")
        value = @resources.find { |resource| resource.fetch(:provide_as) == name }

        if value == nil
          make_test_pending(message)
        end
        value[:id]
      end

      def cleanup
        resources.map do |resource|
          get_resource(resource[:type], resource[:id]).destroy
        end.all?
      end

      def resources
        @resources.reject do |resource|
          nil == get_resource(resource[:type], resource[:id])
        end
      end

      def self.resource_types
        RESOURCE_SERVICES.values.flatten
      end

      private

      def service(resource_type)
        RESOURCE_SERVICES.each do |service, types|
          return service if types.include?(resource_type)
        end

        nil
      end

      def make_test_pending(message)
        RSpec.current_example.example_group_instance.pending(message)
        raise 'Mark as pending'
      end

      def get_resource(type, id)
        FogOpenStack.send(service(type)).send(type).get(id)
      end

    end
  end
end