require_relative 'spec_helper'

describe '.extension_config' do

  let(:validator_config_content) { nil }

  before(:each) do
    @tmpdir = Dir.mktmpdir
    @validator_config = File.join(@tmpdir, 'validator.yml')
    if validator_config_content
      File.write(@validator_config, validator_config_content)
    else
      File.write(@validator_config, "---\n{}")
    end
    ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'] = @validator_config
  end

  after(:each) do
    ENV.delete('BOSH_OPENSTACK_VALIDATOR_CONFIG')
    FileUtils.rm_rf(@tmpdir)
  end

  context 'when missing in validator.yml' do
    it 'returns an empty hash' do
      expect(extension_config).to eq({})
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
      expect(extension_config).to eq({ 'the' => 'hash', 'second' => 'value'})
    end
  end
end