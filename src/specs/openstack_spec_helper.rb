require 'fog/openstack'
require 'yaml'

def compute(fog_params)
  Fog::Compute::OpenStack.new(fog_params)
end

def openstack_params
  openstack_properties = YAML.load_file(ENV['BOSH_OPENSTACK_CPI_CONFIG'])['cloud']['properties']['openstack']
  convert_to_fog_params(openstack_properties)
end

private

def convert_to_fog_params(options)
  {
      :provider => 'OpenStack',
      :openstack_auth_url => options['auth_url'],
      :openstack_username => options['username'],
      :openstack_api_key => options['api_key'],
      :openstack_tenant => options['tenant'],
      :openstack_project_name => options['project'],
      :openstack_domain_name => options['domain'],
      :openstack_region => options['region'],
      :openstack_endpoint_type => options['endpoint_type'],
      :connection_options => options['connection_options']
  }
end