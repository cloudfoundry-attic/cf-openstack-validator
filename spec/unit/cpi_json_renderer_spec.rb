require 'cpi_json_renderer'
require 'YAML'

describe CpiJsonRenderer do

  describe 'end to end' do
    it 'produces the expected result for the given input' do
      validator_config = YAML.load_file("#{File.dirname(__FILE__)}/../assets/validator.yml")
      expected_cpi_config =  YAML.load_file("#{File.dirname(__FILE__)}/../assets/expected_cpi.json")

      rendered_cpi_config = CpiJsonRenderer.render(validator_config)

      expect(rendered_cpi_config).to eq(expected_cpi_config)
    end
  end

  describe '.render' do

    let(:complete_config) do
      {
        'openstack' => {
          'auth_url' => 'https://auth.url/v3',
          'username' => 'username',
          'password' => 'password',
          'domain' => 'domain',
          'project' => 'project'
        }
      }
    end

    describe 'validating input' do

      required_keys = ['auth_url', 'username', 'password', 'domain', 'project']
      key_permutations = required_keys.combination(1).to_a + required_keys.combination(2).to_a

      key_permutations.each do |keys|
        context "when '#{keys.join(', ')}' is missing" do
          it 'raises a standard error' do
            keys.each { |key| complete_config['openstack'].delete(key) }

            expect {
              CpiJsonRenderer.render(complete_config)
            }.to raise_error StandardError, "Required openstack properties missing: '#{keys.join(', ')}'"
          end
        end
      end
    end

    describe 'conversions' do
      it "appends 'auth/tokens' to 'auth_url' parameter" do
        rendered_cpi_config = CpiJsonRenderer.render(complete_config)

        expect(rendered_cpi_config['cloud']['properties']['openstack']['auth_url']).to eq 'https://auth.url/v3/auth/tokens'
      end

      it "replaces 'password' key with 'api_key'" do
        rendered_cpi_config = CpiJsonRenderer.render(complete_config)

        expect(rendered_cpi_config['cloud']['properties']['openstack']['api_key']).to eq complete_config['openstack']['password']
        expect(rendered_cpi_config['cloud']['properties']['openstack']['password']).to be_nil
      end
    end

  end
end