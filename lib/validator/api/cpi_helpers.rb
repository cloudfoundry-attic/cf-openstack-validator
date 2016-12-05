module Validator
  module Api
    module CpiHelpers
      def stemcell_path
        ENV['BOSH_OPENSTACK_STEMCELL_PATH']
      end

      def cpi_path
        ENV['BOSH_OPENSTACK_CPI_PATH']
      end

      def log_path
        ENV['BOSH_OPENSTACK_CPI_LOG_PATH']
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

      def network_spec_with_static_ip
        {
          'default' => {
            'type' => 'manual',
            'ip' => validator_options['static_ip'],
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

      def cpi(cpi_path_arg = cpi_path, log_path_arg = log_path)
        Bosh::Clouds::Config.configure(OpenStruct.new(:logger => Logger.new(STDERR), :cpi_task_log => "#{log_path_arg}/cpi.log"))

        Bosh::Clouds::ExternalCpi.new(cpi_path_arg, 'director-UUID')
      end
    end
  end
end