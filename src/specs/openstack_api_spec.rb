require_relative 'spec_helper'

openstack_suite.context 'API', position: 1, order: :global do

  describe 'rate limit' do
    before(:all) do
      @compute = Validator::Api::FogOpenStack.compute
    end

    it 'is high enough' do
      vm = nil
      Validator::Api::ResourceTracker.create.produce(:servers) do
        vm = create_vm
        vm.id
      end
      begin
        metadata_key = 'rate-limit-test'
        100.times do |i|
          vm.metadata.update(metadata_key => "#{i}")
        end
        expect(vm.metadata.get(metadata_key).value).to eq('99')
      rescue Excon::Errors::RequestEntityTooLarge => e
        fail("Your OpenStack API rate limit is too low. OpenStack error: #{e.message}")
      end
    end
  end

  describe 'Security groups' do
    before do
      begin
        @network = Validator::Api::FogOpenStack.network
      rescue Fog::Errors::NotFound => e
        pending('For this test Neutron is required.')
        raise e
      end
      @configured_security_groups = Validator::Api.configuration.default_vm_type_cloud_properties['security_groups'] || Validator::Api.configuration.openstack['default_security_groups']
    end

    it 'has ingress rule for SSH' do
      error_message = 'BOSH requires incoming SSH access. Expected any security group to have ingress port 22 for TCP open.'
      expect(port_open_in_any_security_group?('ingress', 22, 'tcp', @configured_security_groups)).to be(true), error_message
    end

    it 'has egress rule for HTTP' do
      error_message = 'BOSH requires outgoing web access. Expected any security group to have egress port 80 for TCP open.'
      expect(port_open_in_any_security_group?('egress', 80, 'tcp', @configured_security_groups)).to be(true), error_message
    end

    it 'has egress rule for DNS' do
      error_message = 'BOSH requires DNS access. Expected any security group to have egress port 53 for TCP and UDP open.'
      expect(port_open_in_any_security_group?('egress', 53, 'udp', @configured_security_groups)).to be(true), error_message
      expect(port_open_in_any_security_group?('egress', 53, 'tcp', @configured_security_groups)).to be(true), error_message
    end
  end

  def port_open_in_any_security_group?(direction, port, protocol, security_groups)
    port_open = false
    security_groups.each { |security_group| port_open ||= port_open?(direction, port, protocol, security_group) }
    port_open
  end

  def port_open?(direction, port, protocol, security_group)
    security_group = @network.security_groups.find { |sg| sg.name == security_group }
    rule = security_group.security_group_rules.find { |rule|
      rule.direction == direction && rule.ethertype == 'IPv4' && protocol_included?(rule, protocol) && port_in_range?(port, rule)
    }
    rule != nil
  end

  def port_in_range?(port, rule)
    any_range?(rule) || (rule.port_range_min <= port && port <= rule.port_range_max)
  end

  def any_range?(rule)
    rule.port_range_min == nil && rule.port_range_max == nil
  end

  def protocol_included?(rule, protocol)
    rule.protocol == nil || rule.protocol == protocol
  end
end
