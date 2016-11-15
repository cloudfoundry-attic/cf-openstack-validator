module Validator
  module Api
    class ResourceTracker
      RESOURCE_SERVICES = {
          compute: [:addresses, :flavors, :key_pairs, :servers],
          network: [:networks, :ports, :subnets, :floating_ips, :routers, :security_groups, :security_group_rules],
          image:   [:images],
          volume:  [:volumes, :snapshots]
      }

      TYPE_DEFINITIONS = {
          servers: {wait_block: Proc.new { ready? }},
          volumes: {wait_block: Proc.new { ready? }},
          images: {wait_block: Proc.new { ready? }},
          snapshots: {wait_block: Proc.new { status == 'available' }},
          networks: {wait_block: Proc.new { status == 'ACTIVE' }},
          ports: {wait_block: Proc.new { status == 'ACTIVE' }},
          routers: {wait_block: Proc.new { status == 'ACTIVE' }},
      }

      ##
      # Creates a new resource tracker instance. Each instance manages its own set
      # of resources.
      #
      def self.create
        CfValidator.resources.new_tracker
      end

      def initialize
        @resources = []
      end

      def count
        resources.length
      end

      ##
      # Create and track a resource.
      #
      # = Params
      #   +type+: One of those listed in +RESOURCE_SERVICES+, e.g.: +:servers+
      #   +provide_as+: (optional) The name to be used to access the value via the +consume+ method.
      #                 If it is not given, it cannot be consumed.
      # = Block
      #   The block has to yield an OpenStack resource id. This resource id is used to cleanup the
      #   resource.
      #
      # = Examples
      #   resource_id = resources.provide(resource_type, provide_as: :my_resource_name) { resource_id }
      #   resource_id_not_consumable = resources.provide(resource_type) { resource_id }
      #
      def produce(type, provide_as: nil)
        fog_service = service(type)

        unless fog_service
          raise ArgumentError, "Invalid resource type '#{type}', use #{ResourceTracker.resource_types.join(', ')}"
        end


        if block_given?
          resource_id = yield
          resource = get_resource(type, resource_id)
          if TYPE_DEFINITIONS.key?(type) && TYPE_DEFINITIONS[type].key?(:wait_block)
            resource.wait_for(&TYPE_DEFINITIONS[type][:wait_block])
          end
          @resources << {
              type: type,
              id: resource_id,
              provide_as: provide_as,
              name: resource.name,
              test_description: RSpec.current_example.full_description
          }
          resource_id
        end
      end

      ##
      # Get the resource id of a tracked resource for the given name. If a resource with the given
      # name cannot be found the test calling +consume+ will be marked as pending.
      #
      # = Params
      #   +name+: The name which has been given to +produce+ as +:provide_as+
      #   +message+: (optional) Message to be presented to the user, if the resource cannot be found
      #
      # = Examples
      #   resource_id = resources.provide(resource_type, provide_as: :my_resource_name) { resource_id }
      #   resource_id = resources.consume(:my_resource_name)
      #
      def consumes(name, message = "Required resource '#{name}' does not exist.")
        value = @resources.find { |resource| resource.fetch(:provide_as) == name }

        if value == nil
          Api.skip_test(message)
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

      def get_resource(type, id)
        FogOpenStack.send(service(type)).send(type).get(id)
      end

    end
  end
end
