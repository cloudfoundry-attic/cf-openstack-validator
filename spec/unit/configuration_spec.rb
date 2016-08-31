require_relative 'spec_helper'

describe Validator::Configuration do

  let(:tmpdir) { Dir.mktmpdir }
  let(:validator_config) { File.join(tmpdir, 'validator.yml') }

  subject {
    Validator::Configuration.new(validator_config)
  }

  after(:each) do
    FileUtils.rm_rf(tmpdir)
  end

  describe '.extension_config' do

    let(:validator_config_content) { nil }

    before(:each) do
      if validator_config_content
        File.write(validator_config, validator_config_content)
      else
        File.write(validator_config, "---\n{}")
      end
    end

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

  describe '.openstack_config' do
    it 'uses Converter to convert values from validator.yml' do
      allow(YAML).to receive(:load_file).and_return({'openstack' => {}})
      allow(Converter).to receive(:convert)

      subject.openstack

      expect(Converter).to have_received(:convert)
    end
  end
end