require_relative '../../spec_helper'

module Validator::Api
  describe ResourceTracker do

    let(:compute) { double('compute', servers: resources, volumes: resources) }
    let(:resources) { double('resources', get: resource) }
    let(:resource) { double('resource', name: 'my-resource') }

    before (:each) do
      allow(FogOpenStack).to receive(:compute).and_return(compute)
    end

    describe '.produce' do
      it 'tracks created resources' do
        resource_id = subject.produce(:servers) {
          'id'
        }

        expect(resource_id).to eq('id')
        expect(subject.count).to eq(1)
      end

      context 'given an invalid resource type' do
        it 'raises an ArgumentError' do
          expect {
            subject.produce(:invalid_type)
          }.to raise_error(ArgumentError, "Invalid resource type 'invalid_type', use #{ResourceTracker::RESOURCE_TYPES.join(', ')}")
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

    describe '#count' do
      it 'returns number of tracked resources' do
        expect(subject.count).to eq(0)
      end
    end
  end
end