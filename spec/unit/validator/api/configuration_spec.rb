require_relative '../../spec_helper'

describe Validator::Api::Configuration do

  let(:tmpdir) { Dir.mktmpdir }
  let(:validator_config) { File.join(tmpdir, 'validator.yml') }
  let(:validator_config_content) { nil }

  subject {
    Validator::Api::Configuration.new(validator_config)
  }

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
      allow(YAML).to receive(:load_file).and_return({'openstack' => {}})
      allow(Validator::Converter).to receive(:convert_and_apply_defaults)

      subject.openstack

      expect(Validator::Converter).to have_received(:convert_and_apply_defaults)
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
end