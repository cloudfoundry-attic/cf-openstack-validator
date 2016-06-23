require_relative 'spec_helper'

openstack_suite.context 'API', position: 1, order: :global do

  describe 'rate limit' do

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

  describe 'versions' do

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
