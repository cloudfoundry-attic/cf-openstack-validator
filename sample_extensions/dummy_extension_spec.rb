describe 'My extension' do

  it 'is true' do
    expect(true).to be(true)
  end

  context 'when requiring custom configuration' do
    let(:config) { Validator::Api::configuration.extensions }

    it 'is available' do
      expect(config['custom-config-key']).to eq('custom-config-value')
    end
  end

  context 'when accessing OpenStack API' do

    context 'compute' do
      let(:compute) { Validator::Api::FogOpenStack.compute }

      it 'is provided by the validator' do
        expect(compute.servers).to be_a(Fog::OpenStack::Compute::Servers)
      end
    end

    context 'network' do
      let(:network) { Validator::Api::FogOpenStack.network }

      it 'is provided by the validator' do
        expect(network.networks).to be_a(Fog::OpenStack::Network::Networks)
      end
    end
  end

  context 'when using resource management' do
    let(:compute) { Validator::Api::FogOpenStack.compute }

    before(:all) do
      @resource_tracker = Validator::Api::ResourceTracker.create
    end

    it 'produces a resource' do
      resource_id = @resource_tracker.produce(:volumes, provide_as: :test_volume) {
        compute.volumes.create({
            :name => 'validator-test-volume',
            :description => '',
            :size => 1
        }).id
      }

      expect(resource_id).to_not be_nil
    end

    it 'consumes an existing resource' do
      resource_id = @resource_tracker.consumes(:test_volume)

      expect(resource_id).to_not be_nil
    end

    it 'consumes a non-existing resource' do
      @resource_tracker.consumes(:non_existing_resource)

      fail('Test should have been marked pending')
    end
  end
end
