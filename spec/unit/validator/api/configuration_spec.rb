require_relative '../../spec_helper'

describe Validator::Api::Configuration do

  let(:tmpdir) { Dir.mktmpdir }
  let(:validator_config) { File.join(tmpdir, 'validator.yml') }
  let(:validator_config_content) { nil }

  subject { Validator::Api::Configuration.new(validator_config) }

  before(:each) do
    if validator_config_content
      File.write(validator_config, validator_config_content)
    else
      File.write(validator_config, "---\n{}")
    end
  end

  after(:each) do
    FileUtils.rm_rf(tmpdir)
  end

  describe '#all' do
    let(:validator_config_content) do
      <<EOT
---
openstack:
  key: value
validator:
  another_key: another_value
cloud_config:
  cloud_key: cloud_value
extensions:
  custom_key: custom_value
EOT
    end

    it 'returns the complete configuration' do
      expect(subject.all).to eq(YAML.load(validator_config_content))
    end
  end

  describe '#validator' do
    let(:validator_config_content) do
      <<EOT
---
validator:
  another_key: another_value
EOT
    end

    it 'returns the validator section' do
      expect(subject.validator).to eq({ 'another_key' => 'another_value' })
    end
  end

  describe '#cloud_config' do
    let(:validator_config_content) do
      <<EOT
---
cloud_config:
  another_key: another_value
EOT
    end

    it 'returns the cloud_config section' do
      expect(subject.cloud_config).to eq({ 'another_key' => 'another_value' })
    end
  end

  describe '#default_vm_type_cloud_properties' do
    let(:validator_config_content) do
      <<EOT
---
cloud_config:
  vm_types:
  - cloud_properties:
      another_key: another_value
EOT
    end

    it 'returns the cloud_config section' do
      expect(subject.default_vm_type_cloud_properties).to eq({ 'another_key' => 'another_value' })
    end
  end

  describe '#extensions' do

    let(:validator_config_content) { nil }

    context 'when missing in validator.yml' do
      it 'returns an empty hash' do
        expect(subject.extensions).to eq({})
      end
    end

    context 'when extension configuration is defined in the validator.yml' do
      let(:validator_config_content) do
        <<-EOF
extensions:
  config:
    the: hash
    second: value
        EOF
      end

      it 'returns the hash' do
        expect(subject.extensions).to eq({'the' => 'hash', 'second' => 'value'})
      end
    end
  end

  describe '#openstack' do
    it 'uses Converter to convert values from validator.yml' do
      allow(YAML).to receive(:load_file).and_return({
        'openstack' => { 'auth_url' => '', 'connection_options' => { 'ca_cert' => 'fake-cert' } }
      })

      expect(subject.openstack).to eq('fake-data')
    end
  end

  describe '#custom_extension_paths' do
    context 'with absolute paths' do
      let(:validator_config_content) do
        <<-EOF
extensions:
  paths:
    - /tmp
        EOF
      end

      it 'returns same paths' do
        expect(subject.custom_extension_paths).to eq(['/tmp'])
      end
    end

    context 'with relative paths' do
      let(:validator_config_content) do
        <<-EOF
extensions:
  paths:
    - some-directory
        EOF
      end

      before do
        FileUtils.mkdir_p(File.join(tmpdir, 'some-directory'))
      end

      it 'returns expanded paths' do
        expect(subject.custom_extension_paths).to eq([File.join(tmpdir, 'some-directory')])
      end
    end

    context 'with an empty configuration file' do
      it 'should return an empty array' do
        expect(subject.custom_extension_paths).to eq([])
      end
    end
  end

  describe '#validate_extension_paths' do
    context 'with a valid path' do
      let(:validator_config_content) do
        <<-EOF
extensions:
  paths:
    - existing-directory
        EOF
      end

      before(:each) do
        FileUtils.mkdir(File.join(tmpdir, 'existing-directory'))
      end

      it 'does not raise an error' do
        expect {
          subject.validate_extension_paths
        }.to_not raise_error
      end
    end
    context 'with invalid paths' do
      let(:validator_config_content) do
        <<-EOF
extensions:
  paths:
    - /non-existent-directory
        EOF
      end

      it 'raises error' do
        expect {
          subject.validate_extension_paths
        }.to raise_error Validator::Api::ValidatorError, /'\/non-existent-directory' is not a directory./
      end
    end
  end

  describe '#private_key_path' do
    context 'given a relative path to the config file' do

      let(:validator_config_content) do
        <<-EOF
---
validator:
  private_key_path: ./private/key/path
        EOF
      end

      it 'specifies the private key path relative to the validator.yml' do
        expect(subject.private_key_path).to eq(File.join(tmpdir, '/private/key/path'))
      end
    end

    context 'given an absolute path' do
      let(:validator_config_content) do
        <<-EOF
---
validator:
  private_key_path: /absolute/private/key/path
        EOF
      end

      it 'specifies the private key path relative to the validator.yml' do
        expect(subject.private_key_path).to eq('/absolute/private/key/path')
      end
    end
  end
end
