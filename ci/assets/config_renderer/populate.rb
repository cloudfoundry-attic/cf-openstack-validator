def populate(template, context)
  populated_template = apply_converters(template, validator_config_converters, context)
  merge_optionals(populated_template, context)
end

def validator_config_converters
  {
      'openstack' => {
          'auth_url' => to_string('AUTH_URL'),
          'username' => to_string('USERNAME'),
          'password' => to_string('API_KEY'),
          'domain' => to_string('DOMAIN'),
          'project' => to_string('PROJECT'),
          'default_key_name' => to_string('DEFAULT_KEY_NAME'),
          'default_security_groups' => to_array('DEFAULT_SECURITY_GROUPS'),
          'boot_from_volume' => to_bool('BOOT_FROM_VOLUME'),
          'config_drive' => to_string('CONFIG_DRIVE'),
          'connection_options' => noop
      },
      'validator' => {
          'network_id' => to_string('NETWORK_ID'),
          'floating_ip' => to_string('FLOATING_IP'),
          'static_ip' => to_string('STATIC_IP'),
          'private_key_path' => noop, #'cf-validator.rsa_id',
          'public_image_id' => to_string('PUBLIC_IMAGE_ID'),
          'ntp' => to_array('NTP_SERVER')
      },
      'cloud_config' => {
          'vm_types' => [{
              'name' => noop,
              'cloud_properties' => {
                  'instance_type' => to_string('INSTANCE_TYPE')
              }
          }]
      },
      'extensions' => {
          'paths' => [noop], #['./extensions/']
      }
  }
end

def merge_optionals(config, context)
  config['extensions']['config'] = {
      'custom-config-key' => 'custom-config-value'
  }

  unless context['AVAILABILITY_ZONE']&.empty?
    config['cloud_config']['vm_types'][0]['cloud_properties']['availability_zone'] = context['AVAILABILITY_ZONE']
  end

  unless context['CA_CERT']&.empty?
    config['openstack']['connection_options']['ca_cert'] = context['CA_CERT']
  end

  config
end

def apply_converters(entity, converters, context)
  case
  when entity.is_a?(Hash)
    apply_converter_to_hash(entity, converters, context)
  when entity.is_a?(Array)
    apply_converter_to_array(entity, converters, context)
  else
    entity
  end
end

def apply_converter_to_hash(hash, converters, context)
  hash.map do |key, value|
    converter = converters.fetch(key, noop)
    case
      when converter.is_a?(Hash) && value.is_a?(Hash)
        [key, apply_converter_to_hash(value, converter, context)]
      when converter.is_a?(Array) && value.is_a?(Array)
        [key, apply_converter_to_array(value, converter.first, context)]
      else
        converter.(key, value, context)
    end
  end.compact.to_h
end

def apply_converter_to_array(array, converters, context)
  array.map {|element| apply_converters(element, converters, context)}
end

def to_string(context_name)
  base_converter(context_name) { |context|
    context[context_name]
  }
end

def to_array(context_name)
  base_converter(context_name) { |context|
    context[context_name].split(',').map(&:strip)
  }
end

def to_bool(context_name)
  base_converter(context_name) { |context|
    context[context_name] == 'true'
  }
end

def base_converter(context_name)
  -> (key, value, context) do
    if !context[context_name].nil? && !context[context_name].empty?
      [key, yield(context)]
    else
      [key, value]
    end
  end
end

def noop
  -> (key, value, _) { [key, value] }
end