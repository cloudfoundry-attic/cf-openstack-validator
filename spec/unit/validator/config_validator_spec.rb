require_relative '../spec_helper'

describe 'ValidatorConfig' do

  let(:error_msg_prefix) { "`validator.yml` is not valid:\n" }

  let(:valid_config) do
    {
      'openstack'=> {
        'auth_url'=> '',
        'username'=> '',
        'password'=> '',
        'domain'=> '',
        'project'=> ''
      },
      'validator'=> {
        'network_id' => '',
        'floating_ip' => '',
        'static_ip' => '',
        'private_key_path' => '',
        'public_image_id' => '',
        'releases' => [{
          'name' => 'bosh-openstack-cpi',
          'url' => 'String',
          'sha1' => 'String'
        }]
      },
      'cloud_config'=> {
        'vm_types' => [{
          'name' => 'String',
          'cloud_properties' => {
              'instance_type' => ''
          }
        }]
      }
    }
  end

  it 'validates a given object' do
    expect {
      Validator::ConfigValidator.validate(valid_config)
    }.to_not raise_error
  end

  context 'when a required property is missing' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack'].delete('auth_url')

      expect {
        Validator::ConfigValidator.validate(invalid_config)
      }.to raise_error(Validator::Api::ValidatorError, /auth_url => Missing/)
    end
  end

  context 'when a property has a wrong type' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack']['auth_url'] = 5

      expect {
        Validator::ConfigValidator.validate(invalid_config)
      }.to raise_error(Validator::Api::ValidatorError, /auth_url => Expected instance of String/)
    end
  end

  context 'when an optional property has a wrong type' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack']['stemcell_public_visibility'] = 'hello'

      expect {
        Validator::ConfigValidator.validate(invalid_config)
      }.to raise_error(Validator::Api::ValidatorError, /stemcell_public_visibility => Expected instance of true or false/)
    end
  end

  context 'when cpi release name has a wrong value' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['validator']['releases'][0]['name'] = 'wrong-name'

      expect {
        Validator::ConfigValidator.validate(invalid_config)
      }.to raise_error(Validator::Api::ValidatorError, "#{error_msg_prefix}{ validator => { releases => At index 0: { name => Expected bosh-openstack-cpi, given wrong-name } } }")
    end
  end

  {
    'openstack' => ['auth_url', 'username', 'password', 'domain', 'project'],
    'validator' => ['network_id', 'floating_ip', 'static_ip', 'public_image_id']
  }.each do |outer_key, inner_keys|
    inner_keys.each do |inner_key|
      context "when value '#{outer_key}.#{inner_key}' is '<replace-me>'" do
        it 'returns an error' do
          invalid_config = valid_config
          invalid_config[outer_key][inner_key] = '<replace-me>'

          expect {
            Validator::ConfigValidator.validate(invalid_config)
          }.to raise_error(Validator::Api::ValidatorError, "#{error_msg_prefix}{ #{outer_key} => { #{inner_key} => Found placeholder '<replace-me>' } }")
        end
      end
    end
  end

  context "when value 'cloud_config.vm_types[0].cloud_properties.instance_type' is '<replace-me>'" do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['cloud_config']['vm_types'][0]['cloud_properties']['instance_type'] = '<replace-me>'

      expect {
        Validator::ConfigValidator.validate(invalid_config)
      }.to raise_error(Validator::Api::ValidatorError, "#{error_msg_prefix}{ cloud_config => { vm_types => At index 0: { cloud_properties => { instance_type => Found placeholder '<replace-me>' } } } }")
    end
  end

  context "when value 'extensions.paths[0]' is '<replace-me>'" do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['extensions'] = {'paths' => ['<replace-me>']}

      expect {
        Validator::ConfigValidator.validate(invalid_config)
      }.to raise_error(Validator::Api::ValidatorError, "#{error_msg_prefix}{ extensions => { paths => At index 0: Found placeholder '<replace-me>' } }")
    end
  end

  context "when value 'cloud_config.cloud_config.vm_types.cloud_properties.root_disk.size' is a number" do
    it 'does not return an error' do
      valid_config['cloud_config']['vm_types'][0]['cloud_properties']['root_disk'] = { 'size' => 42 }

      expect {
        Validator::ConfigValidator.validate(valid_config)
      }.to_not raise_error
    end
  end

  context "when value 'cloud_config.cloud_config.vm_types.cloud_properties.root_disk.size' is a string" do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['cloud_config']['vm_types'][0]['cloud_properties']['root_disk'] = { 'size' => 'some-string' }

      expect {
        Validator::ConfigValidator.validate(invalid_config)
      }.to raise_error(Validator::Api::ValidatorError, /size => Expected instance of Numeric, given an instance of String/)
    end
  end
end