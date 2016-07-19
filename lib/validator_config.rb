class ValidatorConfig

  CONFIG_SCHEMA = Membrane::SchemaParser.parse do
    {
        'openstack' => {
            'auth_url' => String,
            'username' => String,
            'password' => String,
            'domain' => String,
            'project' => String,
            optional('region') => String,
            optional('endpoint_type') => String,
            optional('state_timeout') => Numeric,
            optional('stemcell_public_visibility') => bool,
            optional('connection_options') => Hash,
            optional('boot_from_volume') => bool,
            optional('default_key_name') => String,
            optional('default_security_groups') => [String],
            optional('wait_resource_poll_interval') => Integer,
            optional('config_drive') => enum('disk', 'cdrom'),
            optional('human_readable_vm_names') => bool
        },
        'validator' => {
            'network_id' => String,
            'floating_ip' => String,
            'private_key_path' => String,
        },
        'cloud_config' => {
            'vm_types' => [{
                               'name' => String,
                               'cloud_properties' => {
                                   'instance_type' => String
                               }
                           }]
        }
    }
  end

  def self.validate(config)

    begin
      CONFIG_SCHEMA.validate(config)
    rescue Membrane::SchemaValidationError => e
      return false, e.message
    end

    true
  end
end