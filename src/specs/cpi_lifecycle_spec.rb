require 'ostruct'
require 'psych'
require 'json'
require 'rspec/core'
require 'yaml'

require_relative 'spec_helper'
require_relative 'cpi_spec_helper'

def with_cpi(error_message)
  yield if block_given?
rescue => e
  fail "#{error_message} OpenStack error: #{e.message}"
end

def track_resource(resource_type)
  if block_given?
    resource_id = yield
    $resources[resource_type] << resource_id
    resource_id
  end
end

def untrack_resource(resource_type, resource_id)
    $resources[resource_type].delete resource_id
end


openstack_suite.context 'using the CPI', position: 2, order: :global do

  before(:all) {
    @stemcell_path     = stemcell_path
    @cpi_path          = cpi_path
    @validator_options = validator_options
    @cloud_config      = cloud_config
    @log_path          = log_path

    @globals = {
        vm_cid: nil,
        has_vm: nil,
        vm_cid_with_floating_ip: nil,
        has_disk: nil,
        snapshot_cid: nil,
        disk_cid: nil,
        stemcell_cid: nil
    }

    _, @server_thread = create_server
    @cpi = cpi(@cpi_path, @log_path)
    @compute = compute(convert_to_fog_params(openstack_params))
  }

  after(:all) {
    kill_server(@server_thread)
  }

  after(:all) {
    delete_vm @globals[:vm_cid_with_floating_ip]
  }

  it 'can save a stemcell' do
    stemcell_manifest = Psych.load_file(File.join(@stemcell_path, "stemcell.MF"))
    @globals[:stemcell_cid] = with_cpi('Stemcell could not be uploaded') {
      track_resource(:images) {
        @cpi.create_stemcell(File.join(@stemcell_path, "image"), stemcell_manifest["cloud_properties"])
      }
    }
    expect(@globals[:stemcell_cid]).to be
  end

  it 'can create a VM' do
    @globals[:vm_cid] = with_cpi("VM could not be created.") {
      track_resource(:instances) {
        @cpi.create_vm(
            'agent-id',
            @globals[:stemcell_cid],
            default_vm_type_cloud_properties,
            network_spec,
            [],
            {}
        )
      }
    }

    expect(@globals[:vm_cid]).to be
  end

  it 'has vm cid' do
    with_cpi('VM cid could not be found.') {
      @globals[:has_vm] = @cpi.has_vm?(@globals[:vm_cid])
    }

    expect(@globals[:has_vm]).to be true
  end

  it 'can create a disk' do
    @globals[:disk_cid] = with_cpi('Disk could not be created.') {
      track_resource(:volumes) {
        @cpi.create_disk(2048, {}, @globals[:vm_cid])
      }
    }

    expect(@globals[:disk_cid]).to be
  end

  it 'has disk cid' do
    with_cpi('Disk cid could not be found.') {
      @globals[:has_disk] = @cpi.has_disk?(@globals[:disk_cid])
    }

    expect(@globals[:has_disk]).to be true
  end

  it 'can attach the disk to the VM' do
    with_cpi("Disk '#{@globals[:disk_cid]}' could not be attached to VM '#{@globals[:vm_cid]}'.") {
      @cpi.attach_disk(@globals[:vm_cid], @globals[:disk_cid])
    }
  end

  it 'can detach the disk from the VM' do
    with_cpi("Disk '#{@globals[:disk_cid]}' could not be detached from VM '#{@globals[:vm_cid]}'.") {
      @cpi.detach_disk(@globals[:vm_cid], @globals[:disk_cid])
    }
  end

  it 'can take a snapshot' do
    @globals[:snapshot_cid] = with_cpi("Snapshot for disk '#{@globals[:disk_cid]}' could not be taken.") {
      track_resource(:snapshots) {
        @cpi.snapshot_disk(@globals[:disk_cid], {})
      }
    }
  end

  it 'can delete a snapshot' do
    make_pending_unless(@globals[:snapshot_cid], 'No snapshot to delete')

    with_cpi("Snapshot '#{@globals[:snapshot_cid]}' for disk '#{@globals[:disk_cid]}' could not be deleted.") {
      @cpi.delete_snapshot(@globals[:snapshot_cid])
      untrack_resource(:snapshots, @globals[:snapshot_cid])
    }
  end

  it 'can delete the disk' do
    make_pending_unless(@globals[:disk_cid], 'No disk to delete')

    with_cpi("Disk '#{@globals[:disk_cid]}' could not be deleted.") {
      @cpi.delete_disk(@globals[:disk_cid])
      untrack_resource(:volumes, @globals[:disk_cid])
    }
  end

  it 'can delete the VM' do
    make_pending_unless(@globals[:vm_cid], 'No vm to delete')

    with_cpi("VM '#{@globals[:vm_cid]}' could not be deleted.") {
      @cpi.delete_vm(@globals[:vm_cid])
      untrack_resource(:instances, @globals[:vm_cid])
    }
  end

  it 'can attach floating IP to a VM' do
    @globals[:vm_cid_with_floating_ip] = vm_cid = with_cpi("Floating IP could not be attached.") {
      track_resource(:instances) {
        @cpi.create_vm(
          'agent-id',
          @globals[:stemcell_cid],
          default_vm_type_cloud_properties,
          network_spec_with_floating_ip,
          [],
          {}
        )
      }
    }

    vm = @compute.servers.get(vm_cid)
    vm.wait_for { ready? }

    _, err, status = execute_ssh_command_on_vm_with_retry(private_key_path, @validator_options["floating_ip"], "echo hi")

    expect(status.exitstatus).to eq(0), "SSH connection to VM with floating IP didn't succeed.\nError was: #{err}"
  end

  it 'can access the internet' do
    _, err, status = execute_ssh_command_on_vm(private_key_path,
                                            @validator_options["floating_ip"], "nslookup github.com")

    if status.exitstatus > 0
      fail "DNS server might not be reachable from VM with floating IP.\nError is: #{err}"
    end

   _, err, status = execute_ssh_command_on_vm(private_key_path,
                                            @validator_options["floating_ip"], "curl http://github.com")

    expect(status.exitstatus).to eq(0),
                      "Failed to curl http://github.com from VM with floating IP.\nError is: #{err}"
  end

  it 'allows one VM to reach port 22 of another VM within the same network' do
    second_vm_cid = with_cpi("Second VM could not be created.") {
      track_resource(:instances) {
        @cpi.create_vm(
            'agent-id',
            @globals[:stemcell_cid],
            default_vm_type_cloud_properties,
            network_spec,
            [],
            {}
        )
      }
    }

    second_vm = @compute.servers.get(second_vm_cid)
    second_vm_ip = second_vm.addresses.values.first.first['addr']
    second_vm.wait_for { ready? }

    _, err, status = execute_ssh_command_on_vm_with_retry(private_key_path, @validator_options["floating_ip"], "nc -zv #{second_vm_ip} 22")

    expect(status.exitstatus).to eq(0), "Failed to nc port 22 on second VM.\nError is: #{err}"

    delete_vm(second_vm_cid)
  end

  it 'can create large disk' do
    large_disk_cid = with_cpi("Large disk could not be created.\n" +
        'Hint: If you are using DevStack, you need to manually set a' +
        'larger backing file size in your localrc.') {
      track_resource(:volumes){
        @cpi.create_disk(30720, {})
      }
    }

    with_cpi("Large disk '#{large_disk_cid}' could not be deleted.") {
      @cpi.delete_disk(large_disk_cid)
      untrack_resource(:volumes, large_disk_cid)
    }
  end

  it 'can delete a stemcell' do
    make_pending_unless(@globals[:stemcell_cid], 'No stemcell to delete')

    with_cpi('Stemcell could not be deleted') {
      @cpi.delete_stemcell(@globals[:stemcell_cid])
      untrack_resource(:images, @globals[:stemcell_cid])
    }
  end
end
