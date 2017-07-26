require_relative '../spec_helper'

describe Validator::NetworkHelper do
  describe '.next_free_ephemeral_port' do

    it 'uses the right Addrinfo for socket binding' do
      addr_info = Addrinfo.tcp('127.0.0.1', 0)
      expect(Addrinfo).to receive(:tcp).with('127.0.0.1', 0).and_return(addr_info)
      expect_any_instance_of(Socket).to receive(:bind).with(addr_info)

      Validator::NetworkHelper.next_free_ephemeral_port
    end

    it 'returns next ephemeral port number' do
      expect_any_instance_of(Socket).to receive(:local_address).and_return(Addrinfo.tcp('127.0.0.1', 4444))

      expect(Validator::NetworkHelper.next_free_ephemeral_port).to eq(4444)
    end

  end

  describe '.vm_ip_to_ssh' do
    context 'use_external_ip is true' do
      it 'returns the configured floating ip' do
        config = double('config', :validator => {'use_external_ip' => true, 'floating_ip' => 'some-floating-ip'})

        vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh('some-vm-id', config, nil)

        expect(vm_ip_to_ssh).to eq('some-floating-ip')
      end
    end

    context 'use_external_ip is false' do
      it 'returns the vm private ip' do
        config = double('config', :validator => {'use_external_ip' => false})
        server = double('server', :addresses => {'vm-address' => [{'addr' => 'vm-private-ip'}]})
        compute = double('compute', :servers => double('servers', :get => server))

        vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh('some-vm-id', config, compute)

        expect(vm_ip_to_ssh).to eq('vm-private-ip')
      end
    end
  end

  describe 'security groups' do
    let(:port_range_max) { 54 }
    let(:port_range_min) { 50 }
    let(:remote_group_id) { 'some-remote-group-id' }
    let(:security_group_rule) { double('rule', :direction => 'ingress', :ethertype => 'IPv4', :protocol => 'tcp', :port_range_min => port_range_min, :port_range_max => port_range_max, :remote_group_id => remote_group_id) }
    let(:security_group) { double('security_group', :name => 'some-sg', :security_group_rules => [security_group_rule]) }
    let(:network) { double('network', :security_groups => [security_group]) }

    describe '.port_open_in_any_security_group?' do

      it 'returns true when port is open' do
        port_open = Validator::NetworkHelper.port_open_in_any_security_group?('ingress', 53, 'tcp', ['some-sg'], network)

        expect(port_open).to eq(true)
      end

      it 'returns false when port is closed' do
        port_open = Validator::NetworkHelper.port_open_in_any_security_group?('ingress', 49, 'tcp', ['some-sg'], network)

        expect(port_open).to eq(false)
      end
    end

    describe '.ssh_port_open?' do
      let(:port_range_max) { 22 }
      let(:port_range_min) { 22 }
      let(:use_external_ip) { true }

      before(:each) do
        allow(Validator::Api).to receive(:configuration).and_return(double('configuration', :validator => {'use_external_ip' => use_external_ip}))
      end

      context 'use_external_ip is true' do
        context 'ssh allowed from everywhere' do
          let(:remote_group_id) { nil }

          it 'returns true' do
            port_open = Validator::NetworkHelper.ssh_port_open?(['some-sg'], network)

            expect(port_open).to eq(true)
          end
        end

        context 'ssh is not allowed from everywhere' do
          it 'returns false' do
            port_open = Validator::NetworkHelper.ssh_port_open?(['some-sg'], network)

            expect(port_open).to eq(false)
          end
        end
      end

      context 'use_external_ip is false' do
        let(:use_external_ip) { false }

        context 'ssh allowed from everywhere' do
          let(:remote_group_id) { nil }

          it 'returns true' do
            port_open = Validator::NetworkHelper.ssh_port_open?(['some-sg'], network)

            expect(port_open).to eq(true)
          end
        end

        context 'ssh is not allowed from everywhere' do
          it 'returns true' do
            port_open = Validator::NetworkHelper.ssh_port_open?(['some-sg'], network)

            expect(port_open).to eq(true)
          end
        end
      end
    end
  end
end
