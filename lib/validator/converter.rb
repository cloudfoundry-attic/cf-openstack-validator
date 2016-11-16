module Validator
  class Converter

    def self.openstack_defaults
      {
        "default_key_name" => "cf-validator",
        "default_security_groups" => ["default"],
        "wait_resource_poll_interval" => 5,
        "ignore_server_availability_zone" => false,
        "endpoint_type" => "publicURL",
        "state_timeout" => 300,
        "stemcell_public_visibility" => false,
        "boot_from_volume" => false,
        "use_dhcp" => true,
        "human_readable_vm_names" => true
      }
    end

    def self.cpi_config(openstack_params, registry_port)
      {
        "cloud" => {
          "plugin" => "openstack",
          "properties" => {
            "openstack" => openstack_defaults.merge(openstack_params),
            "registry" => {
              "endpoint" => "http://localhost:#{registry_port}",
              "user" => "fake",
              "password" => "fake"
            }
          }
        }
      }
    end

    def self.to_cpi_json(openstack_config)
      registry_port = NetworkHelper.next_free_ephemeral_port

      cpi_config(openstack_config, registry_port)
    end

    private

    PARAM_CONVERTERS = {
        'auth_url' => ->(key, value) {
          if value.end_with?('/auth/tokens')
            [key, value]
          else
            [key, "#{value}/auth/tokens"]
          end
        },
        'password' => ->(_, value) { ['api_key', value] },
        'connection_options' => {
            'ca_cert' => ->(_, value) {
              return nil if value.to_s == ''
              ssl_ca_file_path = File.join(Dir.mktmpdir, 'cacert.pem')
              File.write(ssl_ca_file_path, value)
              ['ssl_ca_file', ssl_ca_file_path]
            }
        }

    }

    def self.convert(openstack_params)
      apply_converters(openstack_params, PARAM_CONVERTERS)
    end

    def self.apply_converters(hash, converters)
      no_op = -> (*args) { args }

      hash.map do |key, value|
        converter = converters.fetch(key, no_op)
        if converter.is_a?(Hash) && value.is_a?(Hash)
          [key, apply_converters(value, converter)]
        else
          converter.call(key, value)
        end
      end.compact.to_h
    end
  end
end