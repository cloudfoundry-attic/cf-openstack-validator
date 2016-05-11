require 'fog/openstack'
require 'yaml'

describe 'API rate limit' do

  before(:all) {
    @openstack_properties = YAML.load_file(ENV['BOSH_OPENSTACK_CPI_CONFIG'])['cloud']['properties']['openstack']
  }


  it 'is high enough' do
    compute = Fog::Compute.new(openstack_params(@openstack_properties))
    begin
      100.times {
        compute.servers
      }
    rescue Excon::Errors::RequestEntityTooLarge => e
      fail("Your OpenStack API rate limit is too low. OpenStack error: #{e.message}")
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
end