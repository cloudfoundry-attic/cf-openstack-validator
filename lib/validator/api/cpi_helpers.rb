module Validator
  module Api
    module CpiHelpers

      def log_path
        RSpec::configuration.options.log_path
      end

      def stemcell_path
        RSpec.configuration.options.stemcell_path
      end

      def cpi_path
        RSpec.configuration.options.cpi_bin_path
      end

      def with_cpi(error_message)
        yield if block_given?
      rescue => e
        fail("#{error_message} OpenStack error: #{e.message}")
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

      def execute_ssh(private_key_path, ip, command)
        stdout, stderr, status = Open3.capture3 "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i #{private_key_path} vcap@#{ip} -C '#{command}'"
        stderr_without_ssh_warning = stderr.gsub(/Warning: Permanently added (.|\s)+? logging and monitoring./, '')
        [stdout, stderr_without_ssh_warning, status]
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

      def error_message(message, command, err, output)
        stderr = 'stderr: '
        stdout = 'stdout: '
        "#{message}\n" \
          "Executed remote command: $ #{command}\n" \
          "#{stderr}#{indent(err, stderr)}\n" \
          "#{stdout}#{indent(output, stdout)}"
      end

      def indent(msg, space_text)
        msg.gsub("\n", "\n#{indentation(space_text)}")
      end

      def indentation(text)
        ' ' * text.size
      end

      def network_spec
        {
          'default' => {
            'type' => 'dynamic',
            'cloud_properties' => {
              'net_id' => Validator::Api.configuration.validator['network_id']
            }
          }
        }
      end

      def network_spec_with_static_ip
        {
          'default' => {
            'type' => 'manual',
            'ip' => Validator::Api.configuration.validator['static_ip'],
            'cloud_properties' => {
              'net_id' => Validator::Api.configuration.validator['network_id']
            }
          }
        }
      end

      def network_spec_with_floating_ip
        {
          'default' => {
            'type' => 'dynamic',
            'cloud_properties' => {
              'net_id' => Validator::Api.configuration.validator['network_id']
            }
          },
          'vip' => {
            'type' => 'vip',
            'ip' => Validator::Api.configuration.validator['floating_ip'],
          }
        }
      end

      def cpi(cpi_path_arg = RSpec.configuration.options.cpi_bin_path, log_path_arg = RSpec.configuration.options.log_path)
        logger = Logger.new("#{log_path_arg}/testsuite.log")
        Validator::ExternalCpi.new(cpi_path_arg, logger, "#{log_path_arg}/cpi.log", "#{log_path_arg}/stats.log")
      end

      def wait_for_swift
        seconds = Validator::Api.configuration.openstack['wait_for_swift'].to_i || 0
        sleep seconds
      end
    end
  end
end
