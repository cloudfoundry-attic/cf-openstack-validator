def extensions_config
  @extensions_config ||= begin
    validator_config = YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])
    validator_config.fetch('extensions', {}).fetch('config', {})
  end
end