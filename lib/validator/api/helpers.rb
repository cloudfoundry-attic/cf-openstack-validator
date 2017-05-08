module Validator
  module Api
    module Helpers
      def red(string)
        "\e[31m#{string}\e[0m"
      end

      def create_vm
        vm = Validator::Api::FogOpenStack.compute.servers.create(server_params)
        wait_for_vm(vm)
        vm
      end

      def server_params
        config = Validator::Api.configuration
        image_id = config.validator['public_image_id']
        flavor_name = config.default_vm_type_cloud_properties['instance_type']
        az = config.default_vm_type_cloud_properties['availability_zone']
        flavor = Validator::Api::FogOpenStack.compute.flavors.find { |f| f.name == flavor_name }
        server_params = {
            name: 'validator-test-vm',
            flavor_ref: flavor.id,
            config_drive: !!config.openstack['config_drive'],
            nics:[{'net_id' => config.validator['network_id']}]
        }

        if az
          server_params.merge!({
              availability_zone: az
          })
        end

        if config.openstack['boot_from_volume']
          server_params.merge!({
              block_device_mapping_v2: [{
                  uuid: image_id,
                  source_type: 'image',
                  destination_type: 'volume',
                  volume_size: 3,
                  boot_index: '0',
                  delete_on_termination: '1'
              }]
          })
        else
          server_params.merge!({
              image_ref: image_id
          })
        end

        server_params
      end

      def wait_for_vm(vm)
        state = nil
        while state != 'ACTIVE' do
          vm.reload
          state = vm.state
          if state == 'ERROR' || state == 'FAILED' || state == 'KILLED'
            fail("Failed to start server. It is in state: #{state}")
          end
        end
      end

      def registry_port
        endpoint = YAML.load_file(RSpec::configuration.options.cpi_config)['cloud']['properties']['registry']['endpoint']
        endpoint.scan(/\d+/).join.to_i
      end

      def create_server(port)
        require 'socket'
        server = TCPServer.new('localhost', port)

        accept_thread = Thread.new {
          loop do
            Thread.start(server.accept) do |socket|
              request = socket.gets
              response = "{\"settings\":\"{}\"}\n"
              headers = create_headers [
                'HTTP/1.1 200 Ok',
                'Content-Type: application/json',
                "Content-Length: #{response.bytesize}",
                'Connection: close']
              socket.print headers
              socket.print "\r\n"
              socket.print response
              socket.close
            end
          end
        }

        [server, accept_thread]
      end

      def create_headers(headers)
        headers.map { |line| "#{line}\r\n" }.join('')
      end

      def kill_server(server_thread)
        Thread.kill(server_thread)
      end

      def openstack_suite
        return @openstack_suite if @openstack_suite
        @openstack_suite = RSpec.describe 'Your OpenStack', order: :openstack do

          before(:all) do
            _, @server_thread = create_server(registry_port)
          end

          after(:all) do
            RSpec::configuration.validator_resources.cleanup unless RSpec::configuration.options.skip_cleanup?
            kill_server(@server_thread)
          end

        end
      end

    end
  end
end
