require_relative('../lib/validator')

ok, error_message = ValidatorConfig.validate(CfValidator.configuration.all)
unless ok
  abort("`validator.yml` is not valid:\n#{error_message}")
end

cpi_config = ARGV.shift
cpi_config_content = JSON.pretty_generate(Converter.to_cpi_json(CfValidator.configuration.openstack))
puts "CPI will use the following configuration: \n#{cpi_config_content}"
File.write(cpi_config, cpi_config_content)
