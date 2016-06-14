require_relative 'spec_helper'
require_relative 'openstack_spec_helper'

describe 'Your OpenStack' do

  before(:all) do
    @openstack_params = openstack_params
    @compute = compute(@openstack_params)
  end

  describe 'API rate limit' do

    it 'is high enough' do
      begin
        servers = @compute.servers
        100.times {
          servers.reload
        }
      rescue Excon::Errors::RequestEntityTooLarge => e
        fail("Your OpenStack API rate limit is too low. OpenStack error: #{e.message}")
      end
    end
  end

  describe 'API version' do

    it 'v1 for Cinder is supported' do
      begin
        Fog::Volume::OpenStack::V1.new(@openstack_params)
      rescue Fog::Errors::NotFound => e
        fail("Your Cinder version is not supported. Supported version is 'v1'. OpenStack error: #{e.message}")
      end
    end

    it 'v1 for Glance is supported' do
      begin
        Fog::Image::OpenStack::V1.new(@openstack_params)
      rescue Fog::Errors::NotFound => e
        fail("Your Glance version is not supported. Supported version is 'v1'. OpenStack error: #{e.message}")
      end
    end
  end

end
