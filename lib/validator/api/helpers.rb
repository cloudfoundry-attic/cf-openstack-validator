module Validator
  module Api
    module Helpers

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
            kill_server(@server_thread)
          end

        end
      end

    end
  end
end
