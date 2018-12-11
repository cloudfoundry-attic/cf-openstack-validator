require_relative 'populate'
require 'yaml'
require 'tmpdir'

describe 'populate' do

  let(:template) {
    {
        'openstack' => {
            'auth_url' => '<replace-me>',
            'username' => '<replace-me>',
            'password' => '<replace-me>',
            'domain' => '<replace-me>',
            'project' => '<replace-me>',
            'default_key_name' => 'cf-validator',
            'default_security_groups' => ['default'],
            'boot_from_volume' => false,
            'config_drive' => nil,
            'wait_for_swift' => '<replace-me>',
            'connection_options' => {
                'ssl_verify_peer' => true,
                'ca_cert' => nil
            }
        },
        'validator' => {
            'network_id' => '<replace-me>',
            'floating_ip' => '<replace-me>',
            'static_ip' => '<replace-me>',
            'private_key_path' => 'cf-validator.rsa_id',
            'ntp' => ['0.pool.ntp.org', '1.pool.ntp.org'],
            'releases' => [{
                'name' => 'bosh-openstack-cpi',
                'url' => 'https://bosh.io/d/github.com/cloudfoundry/bosh-openstack-cpi-release?v=28',
                'sha1' => '5fb85572f3a1bfebcccd6b0b75b0afea9f6df1ea'
            }]
        },
        'cloud_config' => {
            'vm_types' => [{
                'name' => 'default',
                'cloud_properties' => {
                    'instance_type' => '<replace-me>'
                }
            }]
        },
        'extensions' => {
            'paths' => [],
            'config' => {}
        }
    }
  }

  let(:context) {
    {
      'AUTH_URL' => 'AUTH_URL',
      'USERNAME' => 'USERNAME',
      'API_KEY' => 'API_KEY',
      'DOMAIN' => 'DOMAIN',
      'PROJECT' => 'PROJECT',
      'PROJECT_ID' => 'PROJECT_ID',
      'DEFAULT_KEY_NAME' => 'DEFAULT_KEY_NAME',
      'BOOT_FROM_VOLUME' => 'true',
      'CONFIG_DRIVE' => 'CONFIG_DRIVE',
      'WAIT_FOR_SWIFT' => 'WAIT_FOR_SWIFT',
      'NETWORK_ID' => 'NETWORK_ID',
      'FLOATING_IP' => 'FLOATING_IP',
      'STATIC_IP' => 'STATIC_IP',
      'PRIVATE_KEY' => 'PRIVATE_KEY',
      'INSTANCE_TYPE' => 'INSTANCE_TYPE',
      'NTP_SERVER' => 'NTP_SERVER1,NTP_SERVER2, NTP_SERVER3',
      'CA_CERT' => 'CA_CERT',
      'AVAILABILITY_ZONE' => 'AVAILABILITY_ZONE',
      'EXPECTED_FLAVORS' => YAML.dump([
        {
          'name' => 'm1.medium',
          'vcpus' => 2,
          'ram' => 4096,
          'disk' => 40
        }
      ]),
      'EXPECTED_QUOTAS' => YAML.dump({
        'compute' => {
          'ram' => 20
        }
      }),
      'EXPECTED_ENDPOINTS' => YAML.dump([
        {
          'host' => 'host',
          'port' => 20
        }
      ]),
      'AUTO_ANTI_AFFINITY' => 'true'
    }
  }

  before(:each) do
    @tmpdir = Dir.mktmpdir
  end

  after(:each) do
    FileUtils.rm_rf(@tmpdir)
  end

  it 'returns' do
    populated_config = populate(@tmpdir, template, context)

    expect(populated_config).to eq({
        'openstack' => {
            'auth_url' => 'AUTH_URL',
            'username' => 'USERNAME',
            'password' => 'API_KEY',
            'domain' => 'DOMAIN',
            'project' => 'PROJECT',
            'default_key_name' => 'DEFAULT_KEY_NAME',
            'default_security_groups' => ['validator'],
            'boot_from_volume' => true,
            'config_drive' => 'CONFIG_DRIVE',
            'wait_for_swift' => 'WAIT_FOR_SWIFT',
            'connection_options' => {
                'ssl_verify_peer' => true,
                'ca_cert' => 'CA_CERT'
            }
        },
        'validator' => {
            'network_id' => 'NETWORK_ID',
            'floating_ip' => 'FLOATING_IP',
            'static_ip' => 'STATIC_IP',
            'private_key_path' => 'cf-validator.rsa_id',
            'ntp' => ['NTP_SERVER1', 'NTP_SERVER2', 'NTP_SERVER3'],
            'releases' => [{
                'name' => 'bosh-openstack-cpi',
                'url' => 'https://bosh.io/d/github.com/cloudfoundry/bosh-openstack-cpi-release?v=28',
                'sha1' => '5fb85572f3a1bfebcccd6b0b75b0afea9f6df1ea'
            }],
            'use_external_ip' => true
        },
        'cloud_config' => {
            'vm_types' => [{
                'name' => 'default',
                'cloud_properties' => {
                    'instance_type' => 'INSTANCE_TYPE',
                    'availability_zone' => 'AVAILABILITY_ZONE'
                }
            }]
        },
        'extensions' => {
            'paths' => ['./extensions/auto_anti_affinity', './extensions/external_endpoints', './extensions/quotas', './extensions/flavors', './sample_extensions/'],
            'config' => {
                'custom-config-key' => 'custom-config-value',
                'flavors' => {
                    'expected_flavors' => File.join(@tmpdir, 'flavors.yml')
                },
                'quotas' => {
                    'project_id' => 'PROJECT_ID',
                    'expected_quotas' => File.join(@tmpdir, 'quotas.yml')
                },
                'external_endpoints' => {
                    'expected_endpoints' => File.join(@tmpdir, 'endpoints.yml')
                },
                'auto_anti_affinity' => {
                    'project_id' => 'PROJECT_ID'
                }
            }
        }
    })
    expect(File.read(File.join(@tmpdir, 'flavors.yml'))).to eq(context['EXPECTED_FLAVORS'])
    expect(File.read(File.join(@tmpdir, 'quotas.yml'))).to eq(context['EXPECTED_QUOTAS'])
    expect(File.read(File.join(@tmpdir, 'endpoints.yml'))).to eq(context['EXPECTED_ENDPOINTS'])
  end
end
