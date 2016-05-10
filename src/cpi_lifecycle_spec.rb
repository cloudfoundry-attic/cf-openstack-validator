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
    @stemcell_path = ENV['BOSH_OPENSTACK_STEMCELL_PATH']
    @cpi_path = ENV['BOSH_OPENSTACK_CPI_PATH']
    @validator_options = YAML.load_file(ENV['BOSH_OPENSTACK_CPI_CONFIG'])['validator']

    _, @server_thread = create_server
  }

  after(:all) {
    Thread.kill(@server_thread)
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

  let(:cpi) do
    # TODO cpi log should go to $temp_dir/logs
    Bosh::Clouds::Config.configure(OpenStruct.new(:logger => Logger.new(STDERR), :cpi_task_log => 'cpi.log'))

    Bosh::Clouds::ExternalCpi.new(@cpi_path, 'director-UUID')

  end

  xit 'can save a stemcell' do
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
          # TODO stemcell should be uploaded during test run
          # stemcell_cid,
          '9d151067-60ad-43c1-bb75-d3bcd0c6148f',
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

  xit 'can delete a stemcell' do
    with_cpi('Stemcell could not be deleted') {
      cpi.delete_stemcell(@@stemcell_cid)
    }
  end

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
