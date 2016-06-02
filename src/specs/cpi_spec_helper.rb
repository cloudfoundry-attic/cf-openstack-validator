require 'logger'
require 'common/common'
require 'cloud'

def stemcell_path
  ENV['BOSH_OPENSTACK_STEMCELL_PATH']
end

def cpi_path
  ENV['BOSH_OPENSTACK_CPI_PATH']
end

def validator_options
  @validator_options ||= YAML.load_file(ENV['BOSH_OPENSTACK_CPI_CONFIG'])['validator']
end

def log_path
  ENV['BOSH_OPENSTACK_CPI_LOG_PATH']
end

def private_key_path
  private_key_name = validator_options["private_key_name"]
  File.join(File.dirname(__FILE__), "..", "..", private_key_name)
end

def execute_ssh_command_on_vm(private_key_path, ip, command)
  `ssh-keygen -R #{ip}`
  `ssh -o StrictHostKeyChecking=no -i #{private_key_path} vcap@#{ip} -C "#{command}"`
end

def network_spec
  {
      'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
              'net_id' => validator_options['network_id']
          }
      }
  }
end

def network_spec_with_floating_ip
  {
      'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
              'net_id' => validator_options['network_id']
          }
      },
      'vip' => {
          'type' => 'vip',
          'ip' => validator_options['floating_ip'],
      }
  }
end

def cpi(cpi_path, log_path)
  Bosh::Clouds::Config.configure(OpenStruct.new(:logger => Logger.new(STDERR), :cpi_task_log => "#{log_path}/cpi.log"))

  Bosh::Clouds::ExternalCpi.new(cpi_path, 'director-UUID')
end

def create_server
  require 'socket'
  # TODO fake registry port should not be hard coded
  server = TCPServer.new('localhost', 11111)

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

def delete_vm(vm_cid)
  if vm_cid
    begin
      @cpi.delete_vm(vm_cid)
    rescue
    end
  end
end

def create_headers(headers)
  headers.map { |line| "#{line}\r\n" }.join('')
end

def kill_server(server_thread)
  Thread.kill(server_thread)
end