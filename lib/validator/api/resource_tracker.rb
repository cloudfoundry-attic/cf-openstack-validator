module Validator
  module Api
    class ResourceTracker

      RESOURCE_SERVICES = {
          compute: [:flavors, :key_pairs, :servers, :server_groups],
          network: [:networks, :ports, :subnets, :floating_ips, :routers, :security_groups, :security_group_rules],
          image:   [:images],
          volume:  [:volumes, :snapshots],
          storage: [:files, :directories]
      }

      class Base
        extend Validator::Api::CpiHelpers

        def initialize(wait_for: Proc.new { true })
          @wait_for = wait_for
        end

        def name(resource)
          resource.name
        end

        def get_ready(type, id)
          resource = FogOpenStack.send(service(type)).send(type).get(id)
          resource.wait_for(&@wait_for) if resource
          resource
        rescue Fog::Errors::NotFound
          nil
        end

        def destroy(type, id)
          resource = get_ready(type, id)
          if resource
            resource.destroy
          end
        end

        def service(resource_type)
          RESOURCE_SERVICES.each do |service, types|
            return service if types.include?(resource_type)
          end

          nil
        end
      end

      class Volumes < Base
        def name(resource)
          if resource.respond_to?(:name)
            resource.name
          else
            resource.display_name
          end
        end
      end

      class Images < Base

        def get_ready(type, id)
          if id =~ / light$/
            OpenStruct.new(:name => "light_stemcell_#{@id}")
          else
            super(type, id)
          end
        end

        def destroy(_, stemcell_cid)
          Base.cpi.delete_stemcell(stemcell_cid)
          true
        rescue Validator::ExternalCpi::CpiError => e
          false
        end

      end

      class Servers < Base
        def destroy(_, vm_cid)
          Base.cpi.delete_vm(vm_cid)
          true
        rescue Validator::ExternalCpi::CpiError => e
          false
        end
      end

      class Directories < Base
        def name(resource)
          resource.key
        end

        def destroy(type, id)
          directory = FogOpenStack.storage.directories.get(id)
          return unless directory

          directory.files.each do |file|
            begin
              file.destroy
            rescue Fog::Storage::OpenStack::NotFound
              # surpress exception, resource will eventually be consistent
              nil
            end
          end
          Base.wait_for_swift

          begin
            directory.destroy
          rescue Fog::Storage::OpenStack::NotFound
            true
          end
        end
      end

      class Files < Base
        def name(resource)
          resource.key
        end

        def get_ready(type, id)
          directory_id = id[0]
          file_id = id[1]
          directory = super(:directories, directory_id)
          directory.files.get(file_id) if directory
        end

        def destroy(type, id)
          begin
            super(type, id)
          rescue Fog::Storage::OpenStack::NotFound
            true
          end
        end
      end

      class ServerGroups < Base
        def destroy(type, id)
          FogOpenStack.send(:compute).delete_server_group(id)
        end
      end

      RESOURCE_HANDLER = {
        images: Images.new(wait_for: Proc.new { status == 'active' } ),
        servers: Servers.new(wait_for: Proc.new { ready? }),
        volumes: Volumes.new(wait_for: Proc.new { ready? }),
        snapshots: Volumes.new(wait_for: Proc.new { status == 'available' }),
        networks: Base.new(wait_for: Proc.new { status == 'ACTIVE' }),
        ports: Base.new(wait_for: Proc.new { status == 'ACTIVE' }),
        routers: Base.new(wait_for: Proc.new { status == 'ACTIVE' }),
        directories: Directories.new,
        files: Files.new,
        server_groups: ServerGroups.new
      }

      ##
      # Creates a new resource tracker instance. Each instance manages its own set
      # of resources.
      #
      def self.create
        RSpec::configuration.validator_resources.new_tracker
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
          resource_handler = RESOURCE_HANDLER.fetch(type, Base.new)

          resource = resource_handler.get_ready(type, resource_id)

          @resources << {
              type: type,
              id: resource_id,
              provide_as: provide_as,
              name: resource_handler.name(resource),
              test_description: RSpec.current_example&.full_description
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
          RESOURCE_HANDLER.fetch(resource[:type], Base.new).destroy(resource[:type], resource[:id])
        end.all?
      end

      def resources
        @resources.reject do |resource|
          nil == RESOURCE_HANDLER.fetch(resource[:type], Base.new).get_ready(resource[:type], resource[:id])
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
    end
  end
end
