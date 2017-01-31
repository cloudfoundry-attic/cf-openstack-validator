module Validator
  class ConfigValidator

    class ReplacedString < Membrane::Schemas::Base
      REPLACE_ME = /<replace-me>/

      def validate(object)
        Membrane::Schemas::Class.new(String).validate(object)
        fail!(object) if REPLACE_ME =~ object
      end

      def fail!(object)
        emsg = "Found placeholder '#{object}'"
        raise Membrane::SchemaValidationError.new(emsg)
      end
    end

    CONFIG_SCHEMA = Membrane::SchemaParser.parse do
      {
          'openstack' => {
              'auth_url' => ReplacedString.new,
              'username' => ReplacedString.new,
              'password' => ReplacedString.new,
              'domain' => ReplacedString.new,
              'project' => ReplacedString.new,
              optional('region') => String,
              optional('endpoint_type') => String,
              optional('state_timeout') => Numeric,
              optional('stemcell_public_visibility') => bool,
              optional('connection_options') => Hash,
              optional('boot_from_volume') => bool,
              optional('default_key_name') => String,
              optional('default_security_groups') => [String],
              optional('wait_resource_poll_interval') => Integer,
              optional('config_drive') => enum('disk', 'cdrom', nil),
              optional('human_readable_vm_names') => bool
          },
          'validator' => {
              'network_id' => ReplacedString.new,
              'floating_ip' => ReplacedString.new,
              'static_ip' => ReplacedString.new,
              'private_key_path' => String,
              'public_image_id' => ReplacedString.new,
              'releases' => [{
                'name' => 'bosh-openstack-cpi',
                'url' => String,
                'sha1' => String
              }]
          },
          'cloud_config' => {
              'vm_types' => [{
                  'name' => String,
                  'cloud_properties' => {
                      'instance_type' => ReplacedString.new,
                      optional('availability_zone') => String,
                      optional('root_disk') => {
                          'size' => Numeric
                      }
                  }
              }]
          },
          optional('extensions') => {
              optional('paths') => [ReplacedString.new],
              optional('config') => Hash
          }
      }
    end

    def self.validate(config)
      begin
        CONFIG_SCHEMA.validate(config)
      rescue Membrane::SchemaValidationError => e
        raise Validator::Api::ValidatorError, "`validator.yml` is not valid:\n#{e.message}"
      end
    end
  end
end