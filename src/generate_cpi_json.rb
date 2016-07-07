require_relative('../lib/cpi_json_renderer')
require 'YAML'
require 'JSON'

validator_config = YAML.load_file(ARGV.shift)
cpi_config = ARGV.shift
File.write(cpi_config, JSON.pretty_generate(CpiJsonRenderer.render(validator_config)))
