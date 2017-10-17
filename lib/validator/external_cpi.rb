require 'membrane'
require 'open3'

module Validator
  class ExternalCpi
    class CpiError < StandardError; end
    class NonExecutable < CpiError; end
    class InvalidResponse < CpiError; end


    RESPONSE_SCHEMA = Membrane::SchemaParser.parse do
      {
        'result' => any,
        'error' => enum(nil,
          { 'type' => String,
            'message' => String,
            'ok_to_retry' => bool
          }
        ),
        'log' => String
      }
    end

    def initialize(cpi_path, logger, cpi_task_log_path, stats_log_path)
      @cpi_path = cpi_path
      @logger = logger
      @cpi_task_log_path = cpi_task_log_path
      @stats_log_path = stats_log_path
    end

    def current_vm_id(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_stemcell(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_vm(*arguments) invoke_cpi_method(__method__.to_s, *arguments); end
    def info(*arguments) invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def has_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def reboot_vm(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def set_vm_metadata(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def create_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def set_disk_metadata(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def has_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def attach_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def detach_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def snapshot_disk(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def delete_snapshot(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def get_disks(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end
    def ping(*arguments); invoke_cpi_method(__method__.to_s, *arguments); end

    private

    def invoke_cpi_method(method_name, *arguments)
      context = {
        'director_uuid' => 'validator',
        'request_id' => "#{generate_request_id}"
      }

      request_json = JSON.dump(request(method_name, arguments, context))
      redacted_request = request(method_name, redact_arguments(method_name, arguments), redact_context(context))

      cpi_exec_path = checked_cpi_exec_path
      env = {
        'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => ENV['TMPDIR'],
        'BOSH_PACKAGES_DIR' => File.join(File.dirname(cpi_exec_path), 'packages'),
        'BOSH_JOBS_DIR' => File.join(File.dirname(cpi_exec_path), 'jobs')
      }

      @logger.debug("External CPI sending request: #{JSON.dump(redacted_request)} with command: #{cpi_exec_path}")
      cpi_response, stderr, exit_status = nil, nil, nil
      measure = Benchmark.measure {
        cpi_response, stderr, exit_status = Open3.capture3(env, cpi_exec_path, stdin_data: request_json, unsetenv_others: true)
      }
      @logger.debug("External CPI got response: #{cpi_response}, err: #{stderr}, exit_status: #{exit_status}")

      parsed_response = parsed_response(cpi_response)
      validate_response(parsed_response)

      save_cpi_log(parsed_response['log'])
      save_cpi_log(stderr)

      save_stats_log(redacted_request, measure)

      if parsed_response['error']
        handle_error(parsed_response['error'], method_name)
      end

      parsed_response['result']
    end

    def checked_cpi_exec_path
      unless File.executable?(@cpi_path)
        raise NonExecutable, "Failed to run cpi: '#{@cpi_path}' is not executable"
      end
      @cpi_path
    end

    def redact_context(context)
      return context if @properties_from_cpi_config.nil?
      Hash[context.map{|k,v|[k,@properties_from_cpi_config.keys.include?(k) ? '<redacted>' : v]}]
    end

    def redact_arguments(method_name, arguments)
      if method_name == 'create_vm'
        redact_from_env_in_create_vm_arguments(arguments)
      else
        arguments
      end
    end

    def redact_from_env_in_create_vm_arguments(arguments)
      redacted_arguments = arguments.clone
      env = redacted_arguments[5] #{}
      env = redact_all_but(['bosh'], env)
      env['bosh'] = redact_all_but(['group', 'groups'], env.fetch('bosh',{}))
      redacted_arguments[5] = env
      redacted_arguments
    end

    def redact_all_but(keys, hash)
      Hash[hash.map { |k,v| [k, keys.include?(k) ? v.dup : '<redacted>'] }]
    end

    def request(method_name, arguments, context)
      {
        'method' => method_name,
        'arguments' => arguments,
        'context' => context
      }
    end

    def handle_error(error_response, method_name)
      error_type = error_response['type']
      error_message = error_response['message']

      raise Validator::ExternalCpi::CpiError, "CPI error '#{error_type}' with message '#{error_message}' in '#{method_name}' CPI method"
    end

    def save_cpi_log(output)
      File.open(@cpi_task_log_path, 'a') do |f|
        f.write(output)
      end
    end

    def save_stats_log(request, measure)
      StatsLog.new(@stats_log_path).append(request, measure)
    end

    def parsed_response(input)
      begin
        JSON.load(input)
      rescue JSON::ParserError => e
        raise InvalidResponse, "Invalid CPI response - ParserError - #{e.message}"
      end
    end

    def validate_response(response)
      RESPONSE_SCHEMA.validate(response)
    rescue Membrane::SchemaValidationError => e
      raise InvalidResponse, "Invalid CPI response - SchemaValidationError: #{e.message}"
    end

    def generate_request_id
      Random.rand(100000..999999)
    end
  end
end
