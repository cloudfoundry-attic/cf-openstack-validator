def populate(working_directory, config, context)
  if check(context['AUTH_URL'])
    config['openstack']['auth_url'] = context['AUTH_URL']
  end

  if check(context['USERNAME'])
    config['openstack']['username'] = context['USERNAME']
  end

  if check(context['API_KEY'])
    config['openstack']['password'] = context['API_KEY']
  end

  if check(context['DOMAIN'])
    config['openstack']['domain'] = context['DOMAIN']
  end

  if check(context['PROJECT'])
    config['openstack']['project'] = context['PROJECT']
  end

  if check(context['DEFAULT_KEY_NAME'])
    config['openstack']['default_key_name'] = context['DEFAULT_KEY_NAME']
  end

  if check(context['BOOT_FROM_VOLUME'])
    config['openstack']['boot_from_volume'] = to_bool(context['BOOT_FROM_VOLUME'])
  end

  if check(context['CONFIG_DRIVE'])
    config['openstack']['config_drive'] = context['CONFIG_DRIVE']
  end

  if check(context['NETWORK_ID'])
    config['validator']['network_id'] = context['NETWORK_ID']
  end

  if check(context['FLOATING_IP'])
    config['validator']['floating_ip'] = context['FLOATING_IP']
  end

  if check(context['STATIC_IP'])
    config['validator']['static_ip'] = context['STATIC_IP']
  end

  if check(context['PUBLIC_IMAGE_ID'])
    config['validator']['public_image_id'] = context['PUBLIC_IMAGE_ID']
  end

  if check(context['NTP_SERVER'])
    config['validator']['ntp'] = to_array(context['NTP_SERVER'])
  end

  if check(context['INSTANCE_TYPE'])
    config['cloud_config']['vm_types'][0]['cloud_properties']['instance_type'] = context['INSTANCE_TYPE']
  end

  if check(context['AVAILABILITY_ZONE'])
    config['cloud_config']['vm_types'][0]['cloud_properties']['availability_zone'] = context['AVAILABILITY_ZONE']
  end

  if check(context['CA_CERT'])
    config['openstack']['connection_options']['ca_cert'] = context['CA_CERT']
  end

  if context['OBJECT_STORAGE'] == 'true' && check(context['OBJECT_STORAGE_TEMP_URL_KEY'])
    config['extensions']['paths'].unshift('./extensions/object_storage/')
    config['extensions']['config']['object_storage'] = {
          'openstack' => {
              'openstack_temp_url_key' => context['OBJECT_STORAGE_TEMP_URL_KEY']
          }
      }
  end

  config['openstack']['default_security_groups'] = to_array('validator')

  config['extensions']['config']['custom-config-key'] = 'custom-config-value'

  config['extensions']['paths'].unshift('./sample_extensions/')

  config['extensions']['paths'].unshift('./extensions/flavors')

  File.open(File.join(working_directory, 'flavors.yml'), 'w+') do |file|
    file.write(context['EXPECTED_FLAVORS'])
  end
  config['extensions']['config']['flavors'] = {
    'expected_flavors' => File.join(working_directory, 'flavors.yml')
  }

  config['extensions']['paths'].unshift('./extensions/quotas')

  File.open(File.join(working_directory, 'quotas.yml'), 'w+') do |file|
    file.write(context['EXPECTED_QUOTAS'])
  end
  config['extensions']['config']['quotas'] = {
    'project_id' => context['PROJECT_ID']
    'expected_quotas' => File.join(working_directory, 'quotas.yml')
  }

  config
end

def check(value)
  !value.nil? && !value.empty?
end

def to_bool(value)
  value == 'true'
end

def to_array(value)
  value.split(',').map(&:strip)
end
