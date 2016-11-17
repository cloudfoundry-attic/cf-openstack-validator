require_relative '../../spec_helper'

module Validator::Api
  describe ResourceTracker do

    let(:compute) { double('compute', servers: resources, key_pairs: resources, flavors: resources) }
    let(:network) { double('network', networks: resources, routers: resources, subnets: resources, floating_ips: resources, security_groups: resources, security_group_rules: resources, ports: resources) }
    let(:image) { double('image', images: resources) }
    let(:volume) { double('volume', volumes: resources, snapshots: resources) }
    let(:resources) { double('resources', get: resource) }
    let(:resource) { double('resource', name: 'my-resource', wait_for: nil) }

    before (:each) do
      allow(FogOpenStack).to receive(:compute).and_return(compute)
      allow(FogOpenStack).to receive(:network).and_return(network)
      allow(FogOpenStack).to receive(:image).and_return(image)
      allow(FogOpenStack).to receive(:volume).and_return(volume)
    end

    describe '.create' do
      it 'creates new tracker' do
        allow_any_instance_of(RSpec::Core::Configuration).to receive(:validator_resources).and_return(Validator::Resources.new)

        expect(ResourceTracker.create).to be_a(ResourceTracker)
      end
    end

    describe '.produce' do
      it 'tracks created resources' do
        resource_id = subject.produce(:servers) {
          'id'
        }

        expect(resource_id).to eq('id')
        expect(subject.count).to eq(1)
      end

      [:servers, :volumes].each do |type|
        context "when #{type} resource" do
          it 'calls wait_for using "ready?"' do
            allow(resource).to receive(:ready?)
            allow(resource).to receive(:wait_for) { |&block| resource.instance_eval(&block) }

            subject.produce(type) { 'id' }

            expect(resource).to have_received(:ready?)
          end
        end
      end

      (ResourceTracker::RESOURCE_SERVICES.values.flatten - ResourceTracker::TYPE_DEFINITIONS.keys).each do |type|
        context "when #{type} resource" do
          it 'does not call wait_for' do
            subject.produce(type) { 'id' }

            expect(resource).to_not have_received(:wait_for)
          end
        end
      end

      [:networks, :ports, :routers, :snapshots, :images].each do |type|
        context "when #{type} resource" do
          it 'calls wait_for using "status"' do
            allow(resource).to receive(:status)
            allow(resource).to receive(:wait_for) { |&block| resource.instance_eval(&block) }

            subject.produce(type) { 'id' }

            expect(resource).to have_received(:status)
          end
        end
      end

      it 'tracks resources from different services' do
        subject.produce(:servers) { 'server_id' }
        subject.produce(:networks) { 'network_id' }
        subject.produce(:images) { 'image_id' }

        expect(subject.count).to eq(3)
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

        it 'skips the test with a default message' do
          expect(Validator::Api).to receive(:skip_test).with("Required resource 'does_not_exist' does not exist.").and_raise(StandardError)

          expect {
            subject.consumes(:does_not_exist)
          }.to raise_error StandardError

        end

        it 'also supports a custom skip message' do
          expect(Validator::Api).to receive(:skip_test).with('My message.').and_raise(StandardError)

          expect {
            subject.consumes(:does_not_exist, 'My message.')
          }.to raise_error StandardError
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
      before do
        allow(resource).to receive(:destroy).and_return(true)
      end

      it 'destroys all resources' do
        subject.produce(:servers) { 'server_id' }
        subject.produce(:networks) { 'network_id' }
        subject.produce(:images) { 'image_id' }

        subject.cleanup

        expect(resource).to have_received(:destroy).exactly(3).times
      end

      it 'reports true' do
        subject.produce(:servers) { 'server_id' }

        success = subject.cleanup

        expect(success).to eq(true)
      end

      context 'when a resource cannot be destroyed' do
        before do
          allow(resource).to receive(:destroy).and_return(false)
        end

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

      it 'returns all resources existing in openstack' do
        ResourceTracker::RESOURCE_SERVICES.each do |service, types|
          types.each do |type|
            allow(FogOpenStack).to receive_message_chain(service, type).and_return(double('resource_collection', get: double('resource', name: "#{type}-name", wait_for: nil)))

            subject.produce(type) { "#{type}-id" }
          end
        end

        expect(subject.resources.length).to eq((ResourceTracker::RESOURCE_SERVICES.to_a.flatten - ResourceTracker::RESOURCE_SERVICES.keys).length)
      end

      context 'when resources do not exist in openstack anymore' do
        before(:each) do
          ResourceTracker::RESOURCE_SERVICES.each do |service, types|
            types.each do |type|
              allow(FogOpenStack).to receive_message_chain(service, type).and_return(
                double('resource_collection', get: double('resource', name: "#{type}-name", wait_for: nil)),
                double('resource_collection', get: nil)
              )

              subject.produce(type) { "#{type}-id" }
            end
          end
        end

        it 'does not include them' do
          expect(subject.resources.length).to eq(0)
        end
      end

    end

  end
end
