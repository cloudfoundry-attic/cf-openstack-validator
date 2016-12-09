require_relative '../spec_helper'

describe Validator::Converter do

  describe 'end to end' do
    let(:config) { Validator::Api::Configuration.new("#{File.dirname(__FILE__)}/../../assets/validator.yml") }
    it 'produces the expected result for the given input' do
      expected_cpi_config =  YAML.load_file("#{File.dirname(__FILE__)}/../../assets/expected_cpi.json")

      allow(Validator::NetworkHelper).to receive(:next_free_ephemeral_port).and_return(11111)

      expect(Validator::Converter.to_cpi_json(config.openstack)).to eq(expected_cpi_config)
    end
  end

  describe '.to_cpi_json' do
    let(:auth_url) { 'https://auth.url/v3' }
    let(:complete_config) do
      {
          'auth_url' => auth_url,
          'username' => 'username',
          'password' => 'password',
          'domain' => 'domain',
          'project' => 'project'
      }
    end

    describe 'conversions' do
      context "when 'auth_url' does not end with '/auth/tokens'" do
        it "appends 'auth/tokens' to 'auth_url' parameter" do
          rendered_cpi_config = Validator::Converter.convert_and_apply_defaults(complete_config)

          expect(rendered_cpi_config['auth_url']).to eq 'https://auth.url/v3/auth/tokens'
        end
      end

      context "when auth_url ends with '/auth/tokens'" do
        let(:auth_url) { 'https://auth.url/v3/auth/tokens' }

        it "use 'auth_url' parameter as given" do
          rendered_cpi_config = Validator::Converter.convert_and_apply_defaults(complete_config)

          expect(rendered_cpi_config['auth_url']).to eq 'https://auth.url/v3/auth/tokens'
        end
      end

      describe 'default values' do
        before do
          allow(Validator::Converter).to receive(:openstack_defaults).and_return({'default_key' => 'default_value'})
        end
        context 'when value is not set and default value exists' do
          it 'uses default value' do
            expect(complete_config).to_not include(Validator::Converter.openstack_defaults)
            expect(Validator::Converter.convert_and_apply_defaults(complete_config)).to include(Validator::Converter.openstack_defaults)
          end
        end

        context 'when value is manually set for a key which has default value available' do
          let(:complete_config_including_overridden_defaults) { complete_config.merge('default_key' => 'my-value') }
          it 'uses the manually set value' do
            expect(Validator::Converter.convert_and_apply_defaults(complete_config_including_overridden_defaults)).to include('default_key' => 'my-value')
          end
        end
      end

      it "replaces 'password' key with 'api_key'" do
        rendered_cpi_config = Validator::Converter.convert_and_apply_defaults(complete_config)

        expect(rendered_cpi_config['api_key']).to eq complete_config['password']
        expect(rendered_cpi_config['password']).to be_nil
      end

      context 'when connection_options' do
        let(:tmpdir) do
          Dir.mktmpdir
        end

        before(:each) do
          allow(Dir).to receive(:mktmpdir).and_return(tmpdir)
        end

        after(:each) do
          FileUtils.rmdir(tmpdir)
        end

        context '.ca_cert is given' do
          let(:config_with_ca_cert) {
            complete_config.merge({
                'connection_options' => {
                    'ca_cert' => 'crazykey'
                }
            })
          }

          it "replaces 'ca_cert' with 'ssl_ca_file'" do
            rendered_cpi_config = Validator::Converter.convert_and_apply_defaults(config_with_ca_cert)

            expect(rendered_cpi_config['connection_options']['ssl_ca_file']).to eq("#{tmpdir}/cacert.pem")
            expect(rendered_cpi_config['connection_options']['ca_cert']).to be_nil
          end
        end

        [{ name: 'nil', value: nil}, { name: 'empty', value: ''}].each do |falsy_value|

          context ".ca_cert is given #{falsy_value[:name]}" do
            let(:config_with_nil_ca_cert) {
              complete_config.merge({
                  'connection_options' => {
                      'ca_cert' => falsy_value[:value]
                  }
              })
            }

            it "removes 'ca_cert'" do
              rendered_cpi_config = Validator::Converter.convert_and_apply_defaults(config_with_nil_ca_cert)

              expect(rendered_cpi_config['connection_options']['ssl_ca_file']).to be_nil
              expect(rendered_cpi_config['connection_options']['ca_cert']).to be_nil
            end
          end

        end
      end
    end

    describe 'registry configuration' do
      it "uses the next free ephemeral port" do
        expect(Validator::NetworkHelper).to receive(:next_free_ephemeral_port).and_return(60000)

        rendered_cpi_config = Validator::Converter.to_cpi_json(complete_config)

        expect(rendered_cpi_config['cloud']['properties']['registry']['endpoint']).to eq('http://localhost:60000')
      end
    end

  end
end