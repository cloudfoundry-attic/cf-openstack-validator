module Validator
  class Converter

    def self.cacert_path=(value)
      @@cacert_path = value
    end

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
            "openstack" => openstack_params,
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

    def self.base_converters
      {
        'password' => ->(_, value) { ['api_key', value] },
        'connection_options' => {
            'ca_cert' => ->(_, value) {
              return nil if value.to_s == ''
              ssl_ca_file_path = @@cacert_path
              File.write(ssl_ca_file_path, value)
              ['ssl_ca_file', ssl_ca_file_path]
            }
        }
      }
    end

    def self.keystone_v2_converters
      {
        'auth_url' => ->(key, value) {
          if value.end_with?('/tokens')
            [key, value]
          else
            [key, "#{value}/tokens"]
          end
        },
        'domain' => ->(key, value) {
          nil
        },
        'project' => ->(key, value) {
          nil
        }
      }.merge(base_converters)
    end

    def self.keystone_v3_converters
      {
        'auth_url' => ->(key, value) {
          if value.end_with?('/auth/tokens')
            [key, value]
          else
            [key, "#{value}/auth/tokens"]
          end
        },
        'tenant' => ->(key, value) {
          nil
        },
      }.merge(base_converters)
    end

    def self.convert_and_apply_defaults(openstack_params)
      converters = is_v3(openstack_params.fetch('auth_url')) ? keystone_v3_converters : keystone_v2_converters
      apply_converters(openstack_defaults.merge(openstack_params), converters)
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

    def self.is_v3(auth_url)
      auth_url.match(/\/v3(?=\/|$)/)
    end

    private_class_method :apply_converters
  end
end
