require_relative '../../lib/validator'
require_relative '../specs/cpi_spec_helper'

describe 'Custom test' do

  # to be declared and provided by validator.yml:extensions.params
  external_network_name = '<replace_me>'
  image_name = '<replace_me>'

  context 'with openstack cli' do

    it 'create network 1' do
      result = openstack('network', 'create', 'test-network-1')
      provides(:network1, result['id'])
    end

    it 'create network 2' do
      result = openstack('network', 'create', 'test-network-2')
      provides(:network2, result['id'])
    end

    it 'create router 1' do
      result = openstack('router', 'create', 'test-router-1')
      provides(:router1, result['id'])
    end

    it 'create router 2' do
      result = openstack('router', 'create', 'test-router-2')
      provides(:router2, result['id'])
    end

    it 'set external gateway router' do
      router1 = consumes(:router1)
      neutron('router-gateway-set', router1, external_network_name)
    end

    it 'set external gateway router' do
      router2 = consumes(:router2)
      neutron('router-gateway-set', router2, external_network_name)
    end

    it 'create subnetwork of network 1' do
      network1 = consumes(:network1)
      router1 = consumes(:router1)

      result = openstack('subnet', 'create', '--network', network1, '--subnet-range', '10.0.1.0/24', 'network-1-subnet')

      subnet1 = provides(:subnet1, result['id'])
      openstack('router', 'add', 'subnet', router1, subnet1)
    end

    it 'create subnetwork of network 2' do
      network2 = consumes(:network2)
      router2 = consumes(:router2)

      result = openstack('subnet', 'create', '--network', network2, '--subnet-range', '10.0.2.0/24', 'network-2-subnet')

      subnet2 = provides(:subnet2, result['id'])
      openstack('router', 'add', 'subnet', router2, subnet2)
    end

    it 'reserves a floating IP for VM1' do
      result = openstack('ip', 'floating', 'create', external_network_name)

      provides(:floating_ip_1, result['floating_ip_address'])
    end

    it 'create security group 1' do
      result = openstack('security', 'group', 'create', 'test-security-group-1')
      security_group_1 = provides(:security_group_1, result['id'])

      openstack('security', 'group', 'rule', 'create', '--src-ip', "0.0.0.0/0", '--dst-port', '1:65535', security_group_1)
    end

    it 'create security group 2' do
      floating_ip_1 = consumes(:floating_ip_1)

      result = openstack('security', 'group', 'create', 'test-security-group-2')
      security_group_2 = provides(:security_group_2, result['id'])

      openstack('security', 'group', 'rule', 'create', '--src-ip', "#{floating_ip_1}/32", '--dst-port', '1:65535', security_group_2)
    end

    it 'create openstack keypair' do
      tmpdir = Dir.mktmpdir
      private_key = provides(:private_key, File.join(tmpdir, 'id_rsa'))
      public_key = File.join(tmpdir, 'id_rsa.pub')
      `ssh-keygen -C "" -f #{private_key} -N ''`

      expect($?.exitstatus).to eq(0)

      openstack('keypair', 'create', '--public-key', public_key, 'test-key')
    end

    it 'create VM 1' do
      network1 = consumes(:network1)
      security_group_1 = consumes(:security_group_1)
      result = openstack('server', 'create', '--wait', '--flavor', 'm1.small', '--image', image_name, '--nic', "net-id=#{network1}", '--key-name', 'test-key', '--security-group', security_group_1, 'vm-1')

      provides(:vm1, result['id'])
    end

    it 'assign floating IP to VM1' do
      floating_ip_1 = consumes(:floating_ip_1)
      vm1 = consumes(:vm1)

      openstack('ip', 'floating', 'add', floating_ip_1, vm1)
    end

    it 'reserves a floating IP for VM2' do
      result = openstack('ip', 'floating', 'create', external_network_name)
      expect(result).to be_a(Hash)

      provides(:floating_ip_2, result['floating_ip_address'])
    end

    it 'create VM 2' do
      network2 = consumes(:network2)
      security_group_2 = consumes(:security_group_2)

      result = openstack('server', 'create', '--wait', '--flavor', 'm1.small', '--image', image_name, '--nic', "net-id=#{network2}", '--key-name', 'test-key', '--security-group', security_group_2, 'vm-2')

      provides(:vm2, result['id'])
    end

    it 'assign floating IP to VM2' do
      floating_ip_2 = consumes(:floating_ip_2)
      vm2 = consumes(:vm2)

      openstack('ip', 'floating', 'add', floating_ip_2, vm2)
    end

    it 'VM1 can communicate with VM2' do
      consumes(:vm1)
      consumes(:vm2)
      floating_ip_1 = consumes(:floating_ip_1)
      floating_ip_2 = consumes(:floating_ip_2)
      private_key = consumes(:private_key)

      _, _, status = execute_ssh_command_on_vm_with_retry(private_key, floating_ip_1, "nc -zv #{floating_ip_2} 22", user: 'root')

      expect(status.exitstatus).to eq(0)
    end

    after(:all) do

      openstack('ip', 'floating', 'remove', get(:floating_ip_1), get(:vm1), raise_error: false) if get(:floating_ip_1) && get(:vm1)
      openstack('ip', 'floating', 'remove', get(:floating_ip_2), get(:vm2), raise_error: false) if get(:floating_ip_2) && get(:vm2)
      openstack('router', 'remove', 'subnet', get(:router1), get(:subnet1), raise_error: false) if get(:router1) && get(:subnet1)
      openstack('router', 'remove', 'subnet', get(:router2), get(:subnet2), raise_error: false) if get(:router2) && get(:subnet2)

      CfValidator.cli_resources.reverse_each { |resource | delete(resource[:type], resource[:id]) }
    end
  end

end