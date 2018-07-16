require_relative 'spec_helper'

openstack_suite.context 'validating configuration', position: 1, order: :global, configuration: true do
  include_context "resource tracker"

  before(:all) do
    options = RSpec.configuration.options
    @stemcell_path = options.stemcell_path
    @cpi = cpi(options.cpi_bin_path, options.log_path)

    @config = Validator::Api.configuration
    @compute = Validator::Api::FogOpenStack.compute
    stemcell_manifest = YAML.load_file(File.join(@stemcell_path, 'stemcell.MF'))
    stemcell_cid = with_cpi('Stemcell could not be uploaded') {
      @resource_tracker.produce(:images, provide_as: :stemcell_cid) {
        @cpi.create_stemcell(File.join(@stemcell_path, 'image'), stemcell_manifest['cloud_properties'])
      }
    }
    with_cpi('VM with floating IP could not be created.') {
      @resource_tracker.produce(:servers, provide_as: :vm_cid_with_floating_ip) {
        @cpi.create_vm(
          'agent-id',
          stemcell_cid,
          @config.default_vm_type_cloud_properties,
          network_spec_with_floating_ip,
          [],
          {}
        )
      }
    }
    with_cpi('VM with static IP could not be created.') {
      @resource_tracker.produce(:servers, provide_as: :vm_cid_static_ip) {
        @cpi.create_vm(
          'agent-id',
          stemcell_cid,
          @config.default_vm_type_cloud_properties,
          network_spec_with_static_ip,
          [],
          {}
        )
      }
    }
  end

  describe 'cpi' do
    it 'can create large disk' do
      large_disk_cid = with_cpi("Large disk could not be created.\n" +
                                'Hint: If you are using DevStack, you need to manually set a ' +
                                'larger backing file size in your localrc.') {
        @resource_tracker.produce(:volumes, provide_as: :large_disk_cid) {
          @cpi.create_disk(30720, {})
        }
      }

      expect(large_disk_cid).to be
    end

    it 'can delete large disk' do
      large_disk_cid = @resource_tracker.consumes(:large_disk_cid, 'No large disk to delete')

      with_cpi("Large disk '#{large_disk_cid}' could not be deleted.") {
        @cpi.delete_disk(large_disk_cid)
      }
    end
  end

  describe 'rate limit' do
    it 'is high enough' do
      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM to use')
      vm = @compute.servers.get(vm_cid)

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

  describe 'security groups' do
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
      expect(Validator::NetworkHelper.ssh_port_open?(@configured_security_groups, @network)).to be(true), error_message
    end

    it 'has egress rule for HTTP' do
      error_message = 'BOSH requires outgoing web access. Expected any security group to have egress port 80 for TCP open.'
      expect(Validator::NetworkHelper.port_open_in_any_security_group?('egress', 80, 'tcp', @configured_security_groups, @network)).to be(true), error_message
    end

    it 'has egress rule for DNS' do
      error_message = 'BOSH requires DNS access. Expected any security group to have egress port 53 for TCP and UDP open.'
      expect(Validator::NetworkHelper.port_open_in_any_security_group?('egress', 53, 'udp', @configured_security_groups, @network)).to be(true), error_message
      expect(Validator::NetworkHelper.port_open_in_any_security_group?('egress', 53, 'tcp', @configured_security_groups, @network)).to be(true), error_message
    end
  end

  describe 'metadata' do
    it 'can save and retrieve user-data from metadata service' do
      Validator::Api::skip_test('`config_drive` is configured in validator.yml.') if @config.openstack['config_drive']

      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM to use')

      curl_command = 'curl -m 10 http://169.254.169.254/latest/user-data'
      output, err, status = execute_ssh_command_on_vm_with_retry(
        @config.private_key_path,
        Validator::NetworkHelper.vm_ip_to_ssh(vm_cid, @config, @compute),
        curl_command
      )

      if status.exitstatus > 0
        fail error_message('Cannot access metadata service at 169.254.169.254.', curl_command, err, output)
      end

      ['registry', 'server', 'networks'].each do |key|
        expect(JSON.parse(output).keys).to include(key)
      end
    end

    it 'can save and retrieve user-data from config_drive' do
      Validator::Api::skip_test('`config_drive` is not configured in validator.yml.') unless @config.openstack['config_drive']

      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM to use')
      vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh(vm_cid, @config, @compute)
      vcap_password = 'c1oudc0w'
      sudo_command = "echo #{vcap_password}| sudo --prompt \"\" --stdin"
      mount_path = "/tmp/#{SecureRandom.uuid}"
      config_drive_disk_path = '/dev/disk/by-label/config-2'
      command = "#{sudo_command} mkdir #{mount_path} & #{sudo_command} mount #{config_drive_disk_path} #{mount_path}"

      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, command)

      if status.exitstatus > 0
        fail error_message("Cannot mount config drive at '#{config_drive_disk_path}'", command, err, output)
      end

      cat_command = "#{sudo_command} cat #{mount_path}/ec2/latest/user-data"

      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, cat_command)
      execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, "#{sudo_command} umount #{mount_path}")

      if status.exitstatus > 0
        fail error_message("Cannot access metadata at '#{mount_path}/ec2/latest/user-data'", cat_command, err, output)
      end

      ['registry', 'server', 'networks'].each do |key|
        expect(JSON.parse(output).keys).to include(key)
      end
    end
  end

  describe 'connectivity' do
    it 'has configured MTU size' do
      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM with floating IP to use')
      vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh(vm_cid, @config, @compute)
      @resource_tracker.consumes(:vm_cid_static_ip, 'No VM with static IP to use')

      sudo = "echo 'c1oudc0w' | sudo --prompt \"\" --stdin"
      command = "#{sudo} traceroute -M raw -m 1 --mtu #{@config.validator['static_ip']}"

      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, command)

      expect(status.exitstatus).to eq(0),
        error_message("SSH connection didn't succeed. MTU size could not be checked.", command, err, output)

      actual_mtu_size = output.match(/=(\d+)/)

      if actual_mtu_size
        actual_mtu_size = actual_mtu_size[1]
      else
        fail error_message('MTU size could not be checked.', command, err, output)
      end

      recommendation = "The available MTU size on the VMs is '#{actual_mtu_size}'. The desired MTU is '#{@config.validator['mtu_size']}'. "\
        "If you're using GRE or VXLAN, make sure you account for the tunnel overhead buy increasing MTU in your underlay network."
      expect(actual_mtu_size.to_s).to eq(@config.validator['mtu_size'].to_s), recommendation
    end

    it 'can SSH into VM' do
      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM to use')
      vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh(vm_cid, @config, @compute)

      command = 'echo hi'
      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, command)

      expect(status.exitstatus).to eq(0),
        error_message("SSH connection to VM via IP '#{vm_ip_to_ssh}' didn't succeed.", command, err, output)
    end

    it 'can access the internet' do
      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM to use')
      vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh(vm_cid, @config, @compute)

      nslookup_command = 'nslookup github.com'
      output, err, status = execute_ssh_command_on_vm_with_retry(
        @config.private_key_path,
        vm_ip_to_ssh,
        nslookup_command
      )

      if status.exitstatus > 0
        fail error_message("DNS server might not be reachable from VM with IP #{vm_ip_to_ssh}.", nslookup_command, err, output)
      end

      curl_command = 'curl http://github.com'
      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, curl_command)

      expect(status.exitstatus).to eq(0),
        error_message('Failed to curl http://github.com from VM with floating IP.', curl_command, err, output)
    end

    it 'allows a VM to reach the configured NTP server' do
      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM to use')
      vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh(vm_cid, @config, @compute)
      ntp = @config.validator['ntp']
      sudo = "echo 'c1oudc0w' | sudo --prompt \"\" --stdin"
      create_ntpserver_command = "#{sudo} bash -c \"echo #{ntp.join(' ')} | tee /var/vcap/bosh/etc/ntpserver\""
      call_ntpdate_command = "#{sudo} /var/vcap/bosh/bin/ntpdate"

      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, create_ntpserver_command)
      expect(status.exitstatus).to eq(0),
        error_message(
          "Failed to configure NTP server on #{vm_ip_to_ssh}",
          create_ntpserver_command,
          err,
          output
      )

      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, call_ntpdate_command)
      execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, call_ntpdate_command)
      expect(status.exitstatus).to eq(0),
        error_message(
          "Failed to reach any of the following NTP servers: #{ntp.join(', ')}. " +
          'If your OpenStack requires an internal time server, you need to configure it in the validator.yml.',
          call_ntpdate_command,
          err,
          output
      )
    end

    it 'allows one VM to reach port 22 of another VM within the same network' do
      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM to use')
      vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh(vm_cid, @config, @compute)
      stemcell_cid = @resource_tracker.consumes(:stemcell_cid, 'No stemcell to create VM from')

      second_vm_cid = with_cpi('Second VM could not be created.') {
        @resource_tracker.produce(:servers) {
          @cpi.create_vm(
            'agent-id',
            stemcell_cid,
            @config.default_vm_type_cloud_properties,
            network_spec,
            [],
            {}
          )
        }
      }

      second_vm = @compute.servers.get(second_vm_cid)
      second_vm_ip = second_vm.addresses.values.first.first['addr']
      second_vm.wait_for { ready? }

      command = "nc -zv #{second_vm_ip} 22"
      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, command)

      expect(status.exitstatus).to eq(0),
        error_message('Failed to nc port 22 on second VM.', command, err, output)
    end

    it 'allows one VM to reach port 22 of another VM with static IP within the same network' do
      vm_cid = @resource_tracker.consumes(:vm_cid_with_floating_ip, 'No VM with floating IP to use')
      vm_ip_to_ssh = Validator::NetworkHelper.vm_ip_to_ssh(vm_cid, @config, @compute)
      @resource_tracker.consumes(:vm_cid_static_ip, 'No VM with static IP to use')

      command = "nc -zv #{@config.validator['static_ip']} 22"
      output, err, status = execute_ssh_command_on_vm_with_retry(@config.private_key_path, vm_ip_to_ssh, command)

      expect(status.exitstatus).to eq(0),
        error_message('Failed to nc port 22 on VM with.', command, err, output)
    end
  end
end
