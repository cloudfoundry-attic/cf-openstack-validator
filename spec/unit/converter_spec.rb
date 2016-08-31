require_relative 'spec_helper'

describe Converter do

  describe 'end to end' do
    let(:config) { Validator::Configuration.new("#{File.dirname(__FILE__)}/../assets/validator.yml") }
    it 'produces the expected result for the given input' do
      expected_cpi_config =  YAML.load_file("#{File.dirname(__FILE__)}/../assets/expected_cpi.json")

      allow(NetworkHelper).to receive(:next_free_ephemeral_port).and_return(11111)

      expect(Converter.to_cpi_json(config.openstack)).to eq(expected_cpi_config)
    end
  end

  describe '.to_cpi_json' do

    let(:complete_config) do
      {
          'auth_url' => 'https://auth.url/v3',
          'username' => 'username',
          'password' => 'password',
          'domain' => 'domain',
          'project' => 'project'
      }
    end

    describe 'conversions' do
      it "appends 'auth/tokens' to 'auth_url' parameter" do
        rendered_cpi_config = Converter.convert(complete_config)

        expect(rendered_cpi_config['auth_url']).to eq 'https://auth.url/v3/auth/tokens'
      end

      it "replaces 'password' key with 'api_key'" do
        rendered_cpi_config = Converter.convert(complete_config)

        expect(rendered_cpi_config['api_key']).to eq complete_config['password']
        expect(rendered_cpi_config['password']).to be_nil
      end
    end

    describe 'registry configuration' do
      it "uses the next free ephemeral port" do
        expect(NetworkHelper).to receive(:next_free_ephemeral_port).and_return(60000)

        rendered_cpi_config = Converter.to_cpi_json(complete_config)

        expect(rendered_cpi_config['cloud']['properties']['registry']['endpoint']).to eq('http://localhost:60000')
      end
    end

  end
end