module Validator
  module Api
    class ResourceTracker

      RESOURCE_TYPES = [:servers, :volumes, :images, :snapshots]

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
        unless RESOURCE_TYPES.include?(type)
          raise ArgumentError, "Invalid resource type '#{type}', use #{RESOURCE_TYPES.join(', ')}"
        end
        if block_given?
          resource_id = yield
          resource_name = FogOpenStack.compute.send(type).get(resource_id).name
          @resources << {
              resource_type: type,
              resource_id: resource_id,
              provide_as: provide_as,
              resource_name: resource_name,
              test_description: RSpec.current_example.description
          }
          resource_id
        end
      end

      def consumes(name, message = "Required resource '#{name}' does not exist.")
        value = @resources.find { |resource| resource.fetch(:provide_as) == name }

        if value == nil
          make_test_pending(name, message)
        end
        value[:resource_id]
      end

      def cleanup
        resources.each do |value|
          resource = FogOpenStack.compute.send(value[:resource_type]).get(value[:resource_id])
          resource.destroy
        end

        count == 0
      end

      def resources
        @resources.reject do |value|
          resource = FogOpenStack.compute.send(value[:resource_type]).get(value[:resource_id])
          resource == nil
        end
      end

      private

      def make_test_pending(name, message)
        RSpec.current_example.example_group_instance.pending(message)
        raise 'Mark as pending'
      end

    end
  end
end