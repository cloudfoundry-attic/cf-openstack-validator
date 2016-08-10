require 'fog/openstack'
require 'yaml'

def compute(fog_params)
  Fog::Compute::OpenStack.new(fog_params)
end

def openstack_params
  @openstack_properties ||= YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['openstack']
end

def convert_to_fog_params(options)
  {
      :openstack_auth_url => options['auth_url'] + '/auth/tokens',
      :openstack_username => options['username'],
      :openstack_api_key => options['password'],
      :openstack_tenant => options['tenant'],
      :openstack_project_name => options['project'],
      :openstack_domain_name => options['domain'],
      :openstack_region => options['region'],
      :openstack_endpoint_type => options['endpoint_type'] || 'publicURL',
      :connection_options => options['connection_options']
  }
end