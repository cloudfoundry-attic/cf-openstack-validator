require 'ostruct'
require 'psych'
require 'json'
require 'rspec/core'
require 'yaml'

require_relative 'cpi_spec_helper'

def with_cpi(error_message)
  yield if block_given?
rescue => e
  fail "#{error_message} OpenStack error: #{e.message}"
end

describe 'Your OpenStack' do

  before(:all) {
    @stemcell_path     = stemcell_path
    @cpi_path          = cpi_path
    @validator_options = validator_options
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
  }

  after(:all) {
    kill_server(@server_thread)
  }

  after(:all) {
    if @globals[:vm_cid_with_floating_ip]
      with_cpi("VM '#{@globals[:vm_cid_with_floating_ip]}' could not be deleted.") {
        @cpi.delete_vm(@globals[:vm_cid_with_floating_ip])
      }
    end
  }

  it 'can save a stemcell' do
    stemcell_manifest = Psych.load_file(File.join(@stemcell_path, "stemcell.MF"))
    @globals[:stemcell_cid] = with_cpi('Stemcell could not be uploaded') {
      @cpi.create_stemcell(File.join(@stemcell_path, "image"), stemcell_manifest["cloud_properties"])
    }
    expect(@globals[:stemcell_cid]).to be
  end

  it 'can create a VM' do
    @globals[:vm_cid] = with_cpi("VM could not be created.") {
      @cpi.create_vm(
          'agent-id',
          @globals[:stemcell_cid],
          {'instance_type' => 'm1.small'},
          network_spec,
          [],
          {}
      )
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
      @cpi.create_disk(2048, {}, @globals[:vm_cid])
    }

    expect(@globals[:disk_cid]).to be
  end

  it 'has disk cid' do
    with_cpi('Disk cid could not be found.') {
      @globals[:has_disk] = @cpi.has_disk?(@globals[:disk_cid])
    }

    expect(@globals[:has_disk]).to be true
  end

  it 'can attach the disk to the vm' do
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
      @cpi.snapshot_disk(@globals[:disk_cid], {})
    }
  end

  it 'can delete a snapshot' do
    with_cpi("Snapshot '#{@globals[:snapshot_cid]}' for disk '#{@globals[:disk_cid]}' could not be deleted.") {
      @cpi.delete_snapshot(@globals[:snapshot_cid])
    }
  end

  it 'can delete the disk' do
    with_cpi("Disk '#{@globals[:disk_cid]}' could not be deleted.") {
      @cpi.delete_disk(@globals[:disk_cid])
    }
  end

  it 'can delete the VM' do
    with_cpi("VM '#{@globals[:vm_cid]}' could not be deleted.") {
      @cpi.delete_vm(@globals[:vm_cid])
    }
  end

  it 'can attach floating IP to a VM' do
    @globals[:vm_cid_with_floating_ip] = with_cpi("Floating IP could not be attached.") {
      @cpi.create_vm(
        'agent-id',
        @globals[:stemcell_cid],
        { 'instance_type' => 'm1.small' },
        network_spec_with_floating_ip,
        [],
        {}
      )
    }
    #wait for SSH server ot get ready for connections
    20.times do
      execute_ssh_command_on_vm(private_key_path, @validator_options["floating_ip"], "echo hi")
      break if $?.exitstatus == 0
      sleep(3)
    end

    expect($?.exitstatus).to eq(0), "SSH didn't succeed. The return code is #{$?.exitstatus}"
  end

  it 'can access the internet' do
    curl_result = execute_ssh_command_on_vm(private_key_path,
                                            @validator_options["floating_ip"], "curl -v http://github.com 2>&1")

    expect(curl_result).to include('Connected to github.com'),
                           "Failed to curl github.com. Curl response is: #{curl_result}"
  end

  it 'can create large disk' do
    large_disk_cid = with_cpi("Large disk could not be created.\n" +
        'Hint: If you are using DevStack, you need to manually set a' +
        'larger backing file size in your localrc.') {
      @cpi.create_disk(30720, {})
    }

    with_cpi("Large disk '#{large_disk_cid}' could not be deleted.") {
      @cpi.delete_disk(large_disk_cid)
    }
  end

  it 'can delete a stemcell' do
    with_cpi('Stemcell could not be deleted') {
      @cpi.delete_stemcell(@globals[:stemcell_cid])
    }
  end
end
