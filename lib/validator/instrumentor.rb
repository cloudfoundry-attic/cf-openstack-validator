module Validator
  class Instrumentor

    REDACTED = '<redacted>'
    @logger = nil

    def self.logger
      @logger = @logger || Logger.new("#{File.join(RSpec::configuration.options.log_path, 'excon.log')}")
    end

    def self.instrument(name, params = {})
      redacted_params = redact(params)
      logger.debug("#{name} #{redacted_params}")

      evaluated_block = nil
      if block_given?
        measure = Benchmark.measure { evaluated_block = yield }
        stats_log_path = File.join(RSpec::configuration.options.log_path, 'fog_stats.log')
        StatsLog.new(stats_log_path).append({ method: name, arguments: redacted_params }, measure)
        evaluated_block
      end
    end

    def self.redact(params)
      redacted_params = params.dup
      redact_body(redacted_params, 'auth.passwordCredentials.password')
      redact_body(redacted_params, 'server.user_data')
      redact_body(redacted_params, 'auth.identity.password.user.password')
      redact_headers(redacted_params, 'X-Auth-Token')
      redacted_params
    end

    private

    def self.redact_body(params, json_path)
      return unless params.has_key?(:body) && params[:body].is_a?(String)
      return unless params.has_key?(:headers) && params[:headers]['Content-Type'] == 'application/json'

      begin
        json_content = JSON.parse(params[:body])
      rescue JSON::ParserError
        return
      end
      json_content = Redactor.redact(json_content, json_path)
      params[:body] = JSON.dump(json_content)
    end

    def self.redact_headers(params, property)
      return unless params.has_key?(:headers)

      headers = params[:headers] = params[:headers].dup

      headers.store(property, REDACTED)
    end

    def self.fetch_property
      -> (hash, property) { hash.fetch(property, {})}
    end
  end
end
