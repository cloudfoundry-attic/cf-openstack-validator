include Validator::Api::CpiHelpers

describe 'test access to external endpoints' do

  before(:all) do
    @compute = Validator::Api::FogOpenStack.compute
    @config = Validator::Api.configuration
    @resource_tracker = Validator::Api::ResourceTracker.create

    @stemcell_path     = stemcell_path
    @cpi = cpi(cpi_path, log_path)
  end

  config = Validator::Api.configuration.extensions
  endpoints = YAML.load_file( config['external_endpoints']['expected_endpoints']) || []

  it 'prepare image' do
    stemcell_manifest = YAML.load_file(File.join(@stemcell_path, 'stemcell.MF'))
    stemcell_cid = with_cpi('Stemcell could not be uploaded') {
      @resource_tracker.produce(:images, provide_as: :stemcell_cid) {
        @cpi.create_stemcell(File.join(@stemcell_path, 'image'), stemcell_manifest['cloud_properties'])
      }
    }
    expect(stemcell_cid).to be
  end

  it 'prepare VM with image and floating IP' do
    stemcell_cid = @resource_tracker.consumes(:stemcell_cid, 'No stemcell to create VM from')

    vm_cid = with_cpi('Floating IP could not be attached.') {
      @resource_tracker.produce(:servers, provide_as: :vm_cid) {
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

    expect(vm).to be
  end

  context 'connecting to endpoints' do

    endpoints.each do |endpoint|
      it "can access #{endpoint['host']}:#{endpoint['port']}" do
        @resource_tracker.consumes(:vm_cid, 'No VM to check')

        command = "nc -vz #{endpoint['host']} #{endpoint['port']}"

        floating_ip = @config.validator['floating_ip']
        output, err, status =  execute_ssh_command_on_vm_with_retry(
          @config.private_key_path,
          floating_ip,
          command
        )

        expect(status.exitstatus).to eq(0),
          error_message("Failed to reach endpoint from VM with IP #{floating_ip}.", command, err, output)
      end
    end

  end
end
