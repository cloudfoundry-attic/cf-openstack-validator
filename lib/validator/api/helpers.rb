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
        image_id = validator_options['public_image_id']
        flavor_name = default_vm_type_cloud_properties['instance_type']
        flavor = Validator::Api::FogOpenStack.compute.flavors.find { |f| f.name == flavor_name }
        server_params = {
          :name => 'validator-test-vm',
          :image_ref => image_id,
          :flavor_ref => flavor.id,
          :config_drive => !!Validator::Api.configuration.openstack['config_drive'],
          :nics =>[{'net_id' => validator_options['network_id']}]
        }

        if Validator::Api.configuration.openstack['boot_from_volume']
          server_params[:block_device_mapping_v2] = [{
            :uuid => image_id,
            :source_type => 'image',
            :destination_type => 'volume',
            :volume_size => 3,
            :boot_index => '0',
            :delete_on_termination => '1'
          }]
          server_params.delete(:image_ref)
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
        endpoint = YAML.load_file(ENV['BOSH_OPENSTACK_CPI_CONFIG'])['cloud']['properties']['registry']['endpoint']
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
            RSpec::configuration.validator_resources.cleanup unless Validator::Options.new(ENV).skip_cleanup?
            kill_server(@server_thread)
          end

        end
      end

      def default_vm_type_cloud_properties
        cloud_config['vm_types'][0]['cloud_properties']
      end

      def private_key_path
        private_key_path = validator_options['private_key_path']
        # TODO is that a relative path?
        File.join(File.dirname(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG']), private_key_path)
      end

      def validator_options
        @validator_options ||= YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['validator']
      end

      def cloud_config
        @cloud_config ||= YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['cloud_config']
      end
    end
  end
end
