require_relative 'spec_helper'

openstack_suite.context 'using the CPI', position: 2, order: :global, cpi_api: true do
  include_context "resource tracker"

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

    it 'can delete a stemcell' do
      stemcell_cid = @resource_tracker.consumes(:stemcell_cid, 'No stemcell to delete')

      with_cpi('Stemcell could not be deleted') {
        @cpi.delete_stemcell(stemcell_cid)
      }
    end
  end
end
