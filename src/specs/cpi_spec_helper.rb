require 'logger'
require 'common/common'
require 'cloud'
require 'open3'

def stemcell_path
  ENV['BOSH_OPENSTACK_STEMCELL_PATH']
end

def cpi_path
  ENV['BOSH_OPENSTACK_CPI_PATH']
end

def validator_options
  @validator_options ||= YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['validator']
end

def log_path
  ENV['BOSH_OPENSTACK_CPI_LOG_PATH']
end

def private_key_path
  private_key_path = validator_options['private_key_path']
  # TODO is that a relative path?
  File.join(File.dirname(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG']), private_key_path)
end

def execute_ssh_command_on_vm_with_retry(private_key_path, ip, command, time_in_seconds = 60, frequency = 3)
  output, err, status = retry_command(time_in_seconds, frequency){ execute_ssh(private_key_path, ip, command) }

  validate_ssh_connection(err, status)

  [output, err, status]
end

def retry_command(time_in_seconds = 60, frequency = 3)
  start_time = Time.new
  if block_given?
     loop do
       output, err, status = yield

       if status.exitstatus == 0 || Time.now - start_time > time_in_seconds
          break [output, err, status]
       end

       sleep(frequency)
     end
  end
end

def execute_ssh_command_on_vm(private_key_path, ip, command)
  output, err, status = execute_ssh(private_key_path, ip, command)

  validate_ssh_connection(err, status)

  [output, err, status]
end

def execute_ssh(private_key_path, ip, command)
  Open3.capture3 "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i #{private_key_path} vcap@#{ip} -C '#{command}'"
end

def validate_ssh_connection(err, status)
  if status.exitstatus == 255
    if err.include? 'Permission denied (publickey)'
     fail "Failed to ssh to VM with floating IP: Permission denied.\n" +
          "Possible causes:\n" +
          "- SSH key mismatch\n" +
          "- the key has not been provisioned, because the OpenStack metadata service was not reachable\n\n" +
          "Error is: #{err}"
    end

    fail "Failed to ssh to VM with floating IP.\nError is: #{err}"
  end
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
      untrack_resource(:instances, vm_cid)
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

def make_pending_unless(required_value, pending_message)
  unless required_value
    pending(pending_message)
    raise pending_message
  end
end