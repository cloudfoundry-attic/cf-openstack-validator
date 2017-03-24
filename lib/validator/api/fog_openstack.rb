module Validator
  module Api
    class FogOpenStack
      class << self

        def compute
          handle_socket_error do
            Fog::Compute::OpenStack.new(convert_to_fog_params(openstack_params))
          end
        end

        def network
          handle_socket_error do
            Fog::Network::OpenStack.new(convert_to_fog_params(openstack_params))
          end
        end

        def image
          handle_socket_error do
            begin
              Fog::Image::OpenStack::V2.new(convert_to_fog_params(openstack_params))
            rescue Fog::OpenStack::Errors::ServiceUnavailable
              Fog::Image::OpenStack::V1.new(convert_to_fog_params(openstack_params))
            end
          end
        end

        def volume
          handle_socket_error do
            begin
              Fog::Volume::OpenStack::V2.new(convert_to_fog_params(openstack_params))
            rescue Fog::OpenStack::Errors::ServiceUnavailable
              Fog::Volume::OpenStack::V1.new(convert_to_fog_params(openstack_params))
            end
          end
        end

        def storage
          handle_socket_error do
              Fog::Storage::OpenStack.new(convert_to_fog_params(openstack_params))
          end
        end

        private

        def handle_socket_error(&block)
          yield
        rescue Excon::Errors::SocketError => e
          raise ValidatorError, "Could not connect to '#{openstack_params['auth_url']}'", e.backtrace
        end

        def openstack_params
          Api.configuration.openstack
        end

        def convert_to_fog_params(options)
          add_exconn_instrumentor(options)
          {
              :openstack_auth_url => options['auth_url'],
              :openstack_username => options['username'],
              :openstack_api_key => options['api_key'],
              :openstack_tenant => options['tenant'],
              :openstack_project_name => options['project'],
              :openstack_domain_name => options['domain'],
              :openstack_region => options['region'],
              :openstack_endpoint_type => options['endpoint_type'],
              :connection_options => options['connection_options']
          }
        end

        def add_exconn_instrumentor(options)
          if options['connection_options']
            options['connection_options'].merge!({ 'instrumentor' => Validator::Instrumentor })
          end
        end
      end
    end
  end
end
