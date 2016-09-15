require_relative '../../spec_helper'

module Validator::Api
  describe ResourceTracker do

    let(:compute) { double('compute', servers: resources, volumes: resources) }
    let(:network) { double('network', networks: resources, routers: resources) }
    let(:resources) { double('resources', get: resource) }
    let(:resource) { double('resource', name: 'my-resource') }

    before (:each) do
      allow(FogOpenStack).to receive(:compute).and_return(compute)
      allow(FogOpenStack).to receive(:network).and_return(network)
    end

    describe '.produce' do
      it 'tracks created resources' do
        resource_id = subject.produce(:servers) {
          'id'
        }

        expect(resource_id).to eq('id')
        expect(subject.count).to eq(1)
      end

      it 'tracks resources from different services' do
        subject.produce(:servers) { 'server_id' }
        subject.produce(:networks) { 'network_id' }

        expect(subject.count).to eq(2)
      end

      context 'given an invalid resource type' do
        it 'raises an ArgumentError' do
          expect {
            subject.produce(:invalid_type)
          }.to raise_error(ArgumentError, "Invalid resource type 'invalid_type', use #{ResourceTracker::RESOURCE_SERVICES.values.flatten.join(', ')}")
        end
      end
    end

    describe '.consumes' do

      context 'when resource cannot be found' do

        it 'marks a test pending' do |test|
          allow(test.example_group_instance).to receive(:pending)
          expect {
            subject.consumes(:does_not_exist)
          }.to raise_error 'Mark as pending'

          expect(test.example_group_instance).to have_received(:pending).with("Required resource 'does_not_exist' does not exist.")
        end

        it 'supports a custom pending message' do |test|
          allow(test.example_group_instance).to receive(:pending)
          expect {
            subject.consumes(:does_not_exist, 'My message')
          }.to raise_error 'Mark as pending'

          expect(test.example_group_instance).to have_received(:pending).with('My message')
        end

      end

      context 'when resource can be found' do
        before(:each) do
          allow(subject).to receive(:make_test_pending)
          subject.produce(:servers, provide_as: :some_other_cid) {
            'some-other-cid'
          }
          subject.produce(:servers, provide_as: :does_exist) {
            'id'
          }
        end

        it 'returns resource id' do
          resource_id = subject.consumes(:does_exist)

          expect(subject).to_not have_received(:make_test_pending)
          expect(resource_id).to eq('id')
        end
      end
    end

    describe '#cleanup' do
      let(:resource) { double('resource', name: 'my-resource', destroy: true) }

      it 'destroys all resources' do
        subject.produce(:servers) { 'server_id' }
        subject.produce(:networks) { 'network_id' }

        subject.cleanup

        expect(FogOpenStack).to have_received(:compute).exactly(3).times
        expect(FogOpenStack).to have_received(:network).exactly(3).times
      end

      it 'reports true' do
        subject.produce(:servers) { 'server_id' }

        success = subject.cleanup

        expect(success).to eq(true)
      end

      context 'when a resource cannot be destroyed' do

        let(:resource) { double('resource', name: 'my-resource', destroy: false) }

        it 'return false' do
          subject.produce(:servers) { 'server_id' }

          success = subject.cleanup

          expect(success).to eq(false)
        end
      end

    end

    describe '#count' do
      it 'returns number of tracked resources' do
        expect(subject.count).to eq(0)
      end
    end

    describe '#resources' do

      it "returns all resources existing in openstack" do
        ResourceTracker::RESOURCE_SERVICES.each do |service, types|
          types.each do |type|
            allow(FogOpenStack).to receive_message_chain(service, type).and_return(double('resource_collection', get: double('resource', name: "#{type}-name")))

            subject.produce(type) { "#{type}-id" }
          end
        end
        expect(subject.resources.length).to eq(14)
      end

    end

  end
end