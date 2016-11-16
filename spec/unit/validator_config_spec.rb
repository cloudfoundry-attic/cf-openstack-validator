require_relative './spec_helper'

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
        'public_image_id' => ''
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
    ok, err_message = Validator::ValidatorConfig.validate(valid_config)

    expect(err_message).to be_nil
    expect(ok).to eq(true)
  end

  context 'when a required property is missing' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack'].delete('auth_url')

      ok, err_message = Validator::ValidatorConfig.validate(invalid_config)

      expect(err_message).to match(/auth_url => Missing/)
      expect(ok).to eq(false)
    end
  end

  context 'when a property has a wrong type' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack']['auth_url'] = 5

      ok, err_message = Validator::ValidatorConfig.validate(invalid_config)

      expect(err_message).to match(/auth_url => Expected instance of String/)
      expect(ok).to eq(false)
    end
  end

  context 'when an optional property has a wrong type' do
    it 'returns an error' do
      invalid_config = valid_config
      invalid_config['openstack']['stemcell_public_visibility'] = 'hello'

      ok, err_message = Validator::ValidatorConfig.validate(invalid_config)

      expect(err_message).to match(/stemcell_public_visibility => Expected instance of true or false/)
      expect(ok).to eq(false)
    end
  end
end