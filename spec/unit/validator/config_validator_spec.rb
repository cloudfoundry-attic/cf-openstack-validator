require_relative '../spec_helper'

describe 'ValidatorConfig' do

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
    ok, err_message = Validator::ConfigValidator.validate(valid_config)

    expect(err_message).to be_nil
    expect(ok).to eq(true)
  end

  context 'when a required property is missing' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack'].delete('auth_url')

      ok, err_message = Validator::ConfigValidator.validate(invalid_config)

      expect(err_message).to match(/auth_url => Missing/)
      expect(ok).to eq(false)
    end
  end

  context 'when a property has a wrong type' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack']['auth_url'] = 5

      ok, err_message = Validator::ConfigValidator.validate(invalid_config)

      expect(err_message).to match(/auth_url => Expected instance of String/)
      expect(ok).to eq(false)
    end
  end

  context 'when an optional property has a wrong type' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack']['stemcell_public_visibility'] = 'hello'

      ok, err_message = Validator::ConfigValidator.validate(invalid_config)

      expect(err_message).to match(/stemcell_public_visibility => Expected instance of true or false/)
      expect(ok).to eq(false)
    end
  end

  context 'when cpi release name has a wrong value' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['validator']['releases'][0]['name'] = 'wrong-name'

      ok, err_message = Validator::ConfigValidator.validate(invalid_config)

      expect(err_message).to eq('{ validator => { releases => At index 0: { name => Expected bosh-openstack-cpi, given wrong-name } } }')
      expect(ok).to eq(false)
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

          ok, err_message = Validator::ConfigValidator.validate(invalid_config)

          expect(ok).to eq(false)
          expect(err_message).to eq("{ #{outer_key} => { #{inner_key} => Found placeholder '<replace-me>' } }")
        end
      end
    end
  end

  context "when value 'cloud_config.vm_types[0].cloud_properties.instance_type' is '<replace-me>'" do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['cloud_config']['vm_types'][0]['cloud_properties']['instance_type'] = '<replace-me>'

      ok, err_message = Validator::ConfigValidator.validate(invalid_config)

      expect(ok).to eq(false)
      expect(err_message).to eq("{ cloud_config => { vm_types => At index 0: { cloud_properties => { instance_type => Found placeholder '<replace-me>' } } } }")
    end
  end

  context "when value 'extensions.paths[0]' is '<replace-me>'" do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['extensions'] = {'paths' => ['<replace-me>']}

      ok, err_message = Validator::ConfigValidator.validate(invalid_config)

      expect(ok).to eq(false)
      expect(err_message).to eq("{ extensions => { paths => At index 0: Found placeholder '<replace-me>' } }")
    end
  end
end