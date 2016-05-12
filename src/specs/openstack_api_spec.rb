require 'fog/openstack'
require 'yaml'

describe 'Your OpenStack' do

  before(:all) {
    openstack_properties = YAML.load_file(ENV['BOSH_OPENSTACK_CPI_CONFIG'])['cloud']['properties']['openstack']
    @openstack_params = openstack_params(openstack_properties)
  }

  describe 'API rate limit' do

    it 'is high enough' do
      compute = Fog::Compute::OpenStack.new(@openstack_params)
      begin
        100.times {
          compute.servers
        }
      rescue Excon::Errors::RequestEntityTooLarge => e
        fail("Your OpenStack API rate limit is too low. OpenStack error: #{e.message}")
      end
    end
  end

  describe 'API version' do

    it 'v1 for Cinder is supported' do
      begin
        Fog::Image::OpenStack::V1.new(@openstack_params)
      rescue Fog::OpenStack::Errors::ServiceUnavailable => e
        fail("Your Cinder version is not supported. Supported version is 'v1'. OpenStack error: #{e.message}")
      end
    end

    it 'v1 for Glance is supported' do
      begin
        Fog::Volume::OpenStack::V1.new(@openstack_params)
      rescue Fog::OpenStack::Errors::ServiceUnavailable => e
        fail("Your Glance version is not supported. Supported version is 'v1'. OpenStack error: #{e.message}")
      end
    end

  end

end

def openstack_params(options)
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