require_relative('../lib/cpi_json_renderer')
require 'yaml'
require 'json'

validator_config = YAML.load_file(ARGV.shift)
cpi_config = ARGV.shift
cpi_config_content = JSON.pretty_generate(CpiJsonRenderer.render(validator_config))
puts "CPI will use the following configuration: \n#{cpi_config_content}"
File.write(cpi_config, cpi_config_content)
