require 'logger'
require 'common/common'
require 'cloud'
require 'ostruct'
require 'psych'
require 'JSON'
require 'rspec/core'
require 'yaml'


def with_cpi(error_message)
  yield if block_given?
rescue => e
  fail "#{error_message} OpenStack error: #{e.message}"
end

describe 'Your OpenStack' do

  before(:all) {
    @stemcell_path     = ENV['BOSH_OPENSTACK_STEMCELL_PATH']
    @cpi_path          = ENV['BOSH_OPENSTACK_CPI_PATH']
    @validator_options = YAML.load_file(ENV['BOSH_OPENSTACK_CPI_CONFIG'])['validator']
    @log_path          = ENV['BOSH_OPENSTACK_CPI_LOG_PATH']

    _, @server_thread = create_server
    cpi
  }

  after(:all) {
    Thread.kill(@server_thread)
  }

  after(:all) {
    if @@vm_cid_with_floating_ip
      with_cpi("VM '#{@@vm_cid_with_floating_ip}' could not be deleted.") {
        cpi.delete_vm(@@vm_cid_with_floating_ip)
      }
    end
  }

  let(:network_spec) do
    {
        'default' => {
            'type' => 'dynamic',
            'cloud_properties' => {
                'net_id' => @validator_options['network_id']
            }
        }
    }
  end

  let(:network_spec_with_floating_ip) do
    {
        'default' => {
            'type' => 'dynamic',
            'cloud_properties' => {
                'net_id' => @validator_options['network_id']
            }
        },
        'vip' => {
          'type' => 'vip',
          'ip' => @validator_options['floating_ip'],
        }
    }
  end

  def cpi
    @cpi ||= begin
      # TODO cpi log should go to $temp_dir/logs
      Bosh::Clouds::Config.configure(OpenStruct.new(:logger => Logger.new(STDERR), :cpi_task_log => "#{@log_path}/cpi.log"))

      Bosh::Clouds::ExternalCpi.new(@cpi_path, 'director-UUID')
    end
  end

  it 'can save a stemcell' do
    stemcell_manifest = Psych.load_file(File.join(@stemcell_path, "stemcell.MF"))
    @@stemcell_cid = with_cpi('Stemcell could not be uploaded') {
      cpi.create_stemcell(File.join(@stemcell_path, "image"), stemcell_manifest["cloud_properties"])
    }

    expect(@@stemcell_cid).to be
  end

  it 'can create a VM' do
    @@vm_cid = with_cpi("VM could not be created.") {
      cpi.create_vm(
          'agent-id',
          @@stemcell_cid,
          {'instance_type' => 'm1.small'},
          network_spec,
          [],
          {}
      )
    }

    expect(@@vm_cid).to be
  end

  it 'has vm cid' do
    with_cpi('VM cid could not be found.') {
      @@has_vm = cpi.has_vm?(@@vm_cid)
    }

    expect(@@has_vm).to be true
  end

  it 'can create a disk' do
    @@disk_cid = with_cpi('Disk could not be created.') {
      cpi.create_disk(2048, {}, @@vm_cid)
    }

    expect(@@disk_cid).to be
  end

  it 'has disk cid' do
    with_cpi('Disk cid could not be found.') {
      @@has_disk = cpi.has_disk?(@@disk_cid)
    }

    expect(@@has_disk).to be true
  end

  it 'can attach the disk to the vm' do
    with_cpi("Disk '#{@@disk_cid}' could not be attached to VM '#{@@vm_cid}'.") {
      cpi.attach_disk(@@vm_cid, @@disk_cid)
    }
  end

  it 'can detach the disk from the VM' do
    with_cpi("Disk '#{@@disk_cid}' could not be detached from VM '#{@@vm_cid}'.") {
      cpi.detach_disk(@@vm_cid, @@disk_cid)
    }
  end

  it 'can take a snapshot' do
    @@snapshot_cid = with_cpi("Snapshot for disk '#{@@disk_cid}' could not be taken.") {
      cpi.snapshot_disk(@@disk_cid, {})
    }
  end

  it 'can delete a snapshot' do
    with_cpi("Snapshot '#{@@snapshot_cid}' for disk '#{@@disk_cid}' could not be deleted.") {
      cpi.delete_snapshot(@@snapshot_cid)
    }
  end

  it 'can delete the disk' do
    with_cpi("Disk '#{@@disk_cid}' could not be deleted.") {
      cpi.delete_disk(@@disk_cid)
    }
  end

  it 'can delete the VM' do
    with_cpi("VM '#{@@vm_cid}' could not be deleted.") {
      cpi.delete_vm(@@vm_cid)
    }
  end

  it 'can attach floating IP to a VM' do
    @@vm_cid_with_floating_ip = with_cpi("Floating IP could not be attached.") {
      cpi.create_vm(
        'agent-id',
        @@stemcell_cid,
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
      cpi.create_disk(30720, {})
    }

    with_cpi("Large disk '#{large_disk_cid}' could not be deleted.") {
      cpi.delete_disk(large_disk_cid)
    }
  end

  it 'can delete a stemcell' do
    with_cpi('Stemcell could not be deleted') {
      cpi.delete_stemcell(@@stemcell_cid)
    }
  end
end

def private_key_path
  private_key_name = @validator_options["private_key_name"]
  File.join(File.dirname(__FILE__), "..", "..", private_key_name)
end

def execute_ssh_command_on_vm(private_key_path, ip, command)
  `ssh -o StrictHostKeyChecking=no -i #{private_key_path} vcap@#{ip} -C "#{command}"`
end

def create_server
  require 'socket'
  # TODO fake registry port should not be hard coded
  server = TCPServer.new('localhost', 11111)

  accept_thread = Thread.new {
    loop do
      Thread.start(server.accept) do |socket|
        request = socket.gets
        response = "{\"settings\":\"{}\"}\n"
        headers = create_headers [
                                     'HTTP/1.1 200 Ok',
                                     'Content-Type: application/json',
                                     "Content-Length: #{response.bytesize}",
                                     'Connection: close']
        socket.print headers
        socket.print "\r\n"
        socket.print response
        socket.close
      end
    end
  }

  [server, accept_thread]
end

def create_headers(headers)
  headers.map { |line| "#{line}\r\n" }.join('')
end
