require_relative 'spec_helper'

include Validator::Api::CpiHelpers

def with_cpi(error_message)
  yield if block_given?
rescue => e
  fail("#{error_message} OpenStack error: #{e.message}")
end

openstack_suite.context 'using the CPI', position: 2, order: :global do

  before(:all) {
    options = RSpec.configuration.options
    @stemcell_path = options.stemcell_path
    @cpi = cpi(options.cpi_bin_path, options.log_path)
  }

  it 'verifying that the CPI is executable', cpi_only: true do
    cpi_info = with_cpi('CPI could not be called') {
      @cpi.info
    }

    expect(cpi_info).to be
  end

  context 'against OpenStack' do

    before(:all) {
      @config = Validator::Api.configuration
      @resource_tracker = Validator::Api::ResourceTracker.create
      @compute = Validator::Api::FogOpenStack.compute
    }

    it 'can save a stemcell' do
      stemcell_manifest = YAML.load_file(File.join(@stemcell_path, 'stemcell.MF'))
      stemcell_cid = with_cpi('Stemcell could not be uploaded') {
        @resource_tracker.produce(:images, provide_as: :stemcell_cid) {
          @cpi.create_stemcell(File.join(@stemcell_path, 'image'), stemcell_manifest['cloud_properties'])
        }
      }
      expect(stemcell_cid).to be
    end

    it 'can create a VM' do
      stemcell_id = @resource_tracker.consumes(:stemcell_cid, 'No stemcell available')

      vm_cid = with_cpi('VM could not be created.') {
        @resource_tracker.produce(:servers, provide_as: :vm_cid) {
          @cpi.create_vm(
            'agent-id',
            stemcell_id,
            @config.default_vm_type_cloud_properties,
            network_spec,
            [],
            {}
          )
        }
      }

      expect(vm_cid).to be
    end

    it 'has VM cid' do
      vm_cid = @resource_tracker.consumes(:vm_cid, 'No VM to check')

      has_vm = with_cpi('VM cid could not be found.') {
        @cpi.has_vm(vm_cid)
      }

      expect(has_vm).to be true
    end

    it 'can set VM metadata' do
      vm_cid = @resource_tracker.consumes(:vm_cid, 'No VM to set metadata for')

      server_metadata = @compute.servers.get(vm_cid).metadata
      fail_message = "VM metadata registry key was not written for VM with ID #{vm_cid}."

      expect(server_metadata.get('registry_key')).not_to be_nil, fail_message
    end

    it 'can create a disk in same AZ as VM' do
      vm_cid = @resource_tracker.consumes(:vm_cid, 'No VM to create disk for')

      disk_cid = with_cpi('Disk could not be created.') {
        @resource_tracker.produce(:volumes, provide_as: :disk_cid) {
          @cpi.create_disk(2048, {}, vm_cid)
        }
      }

      expect(disk_cid).to be
    end

    it 'has disk cid' do
      disk_cid = @resource_tracker.consumes(:disk_cid, 'No disk to check')

      has_disk = with_cpi('Disk cid could not be found.') {
        @cpi.has_disk(disk_cid)
      }

      expect(has_disk).to be true
    end

    it 'can set disk metadata' do
      disk_cid = @resource_tracker.consumes(:disk_cid, 'No disk to check')

      with_cpi('CPI failed to set disk metadata.') {
        @cpi.set_disk_metadata(disk_cid, {'validator-test' => 'test-disk-tagging'})
      }
    end

    it 'can attach the disk to the VM' do
      vm_cid = @resource_tracker.consumes(:vm_cid, 'No VM to attach disk to')
      disk_cid = @resource_tracker.consumes(:disk_cid, 'No disk to attach')

      with_cpi("Disk '#{disk_cid}' could not be attached to VM '#{vm_cid}'.") {
        @cpi.attach_disk(vm_cid, disk_cid)
      }
    end

    it 'can detach the disk from the VM' do
      vm_cid = @resource_tracker.consumes(:vm_cid, 'No VM to detach disk from')
      disk_cid = @resource_tracker.consumes(:disk_cid, 'No disk to detach')

      with_cpi("Disk '#{disk_cid}' could not be detached from VM '#{vm_cid}'.") {
        @cpi.detach_disk(vm_cid, disk_cid)
      }
    end

    it 'can take a snapshot' do
      disk_cid = @resource_tracker.consumes(:disk_cid, 'No disk to create snapshot from')
      metadata = {'director_name' => 'validator-test', 'job' => 'validator-test', 'instance_id' => 'validator-test'}

      snapshot_cid = with_cpi("Snapshot for disk '#{disk_cid}' could not be taken.") {
        @resource_tracker.produce(:snapshots, provide_as: :snapshot_cid) {
          @cpi.snapshot_disk(disk_cid, metadata)
        }
      }

      expect(snapshot_cid).to be
    end

    it 'can delete a snapshot' do
      snapshot_cid = @resource_tracker.consumes(:snapshot_cid, 'No snapshot to delete')
      disk_cid = @resource_tracker.consumes(:disk_cid, 'No disk to delete snapshot from')

      with_cpi("Snapshot '#{snapshot_cid}' for disk '#{disk_cid}' could not be deleted.") {
        @cpi.delete_snapshot(snapshot_cid)
      }
    end

    it 'can delete the disk' do
      disk_cid = @resource_tracker.consumes(:disk_cid, 'No disk to delete')

      with_cpi("Disk '#{disk_cid}' could not be deleted.") {
        @cpi.delete_disk(disk_cid)
      }
    end

    it 'can delete the VM' do
      vm_cid = @resource_tracker.consumes(:vm_cid, 'No vm to delete')

      with_cpi("VM '#{vm_cid}' could not be deleted.") {
        @cpi.delete_vm(vm_cid)
      }
    end

    it 'can attach floating IP to a VM' do
      stemcell_cid = @resource_tracker.consumes(:stemcell_cid, 'No stemcell to create VM from')

      vm_cid = with_cpi('Floating IP could not be attached.') {
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

      vm = @compute.servers.get(vm_cid)
      vm.wait_for { ready? }
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

    it 'can create a VM with static IP' do
      stemcell_cid = @resource_tracker.consumes(:stemcell_cid, 'No stemcell to create VM from')

      vm_cid_static_ip = with_cpi('VM with static IP could not be created.') {
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

      expect(vm_cid_static_ip).to be
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

    it 'can create large disk' do
      large_disk_cid = with_cpi("Large disk could not be created.\n" +
        'Hint: If you are using DevStack, you need to manually set a ' +
        'larger backing file size in your localrc.') {
        @resource_tracker.produce(:volumes, provide_as: :large_disk_cid){
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

    it 'can delete a stemcell' do
      stemcell_cid = @resource_tracker.consumes(:stemcell_cid, 'No stemcell to delete')

      with_cpi('Stemcell could not be deleted') {
        @cpi.delete_stemcell(stemcell_cid)
      }
    end
  end

  def parse_curl_error(error)
    curl_err = error.match(/curl: \(\d+\) (.+)/)
    return "Error is: #{curl_err[1]}\n" unless curl_err.nil?
    nil
  end
end
