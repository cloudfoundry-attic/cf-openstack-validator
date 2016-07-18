require_relative 'spec_helper'

describe ResourceTracker do

  describe '#count' do
    it 'returns number of tracked resources' do
      expect(subject.count).to eq(0)
    end
  end

  describe '#track' do
    it 'takes the return value of a given block and tracks the resource' do
      cloud_id = subject.track(:servers) {
        '1234-1234-1234-1234'
      }

      expect(cloud_id).to eq('1234-1234-1234-1234')
      expect(subject.count).to eq(1)
    end

    context 'given an invalid resource type' do
      it 'raises an ArgumentError' do

        expect {
          subject.track(:invalid_type)
        }.to raise_error(ArgumentError, "Invalid resource type 'invalid_type', use #{ResourceTracker::RESOURCE_TYPES.join(', ')}")
      end
    end
  end

  describe '#summary' do
    it 'returns all tracked resources as printable string' do
      subject.track(:servers) { '1234-1234-1234-1234' }
      subject.track(:volumes) { '1111-1111-1111-1111' }
      subject.track(:volumes) { '0000-0000-0000-0000' }

      expect(subject.summary).to eq(
        "The following resources might not have been cleaned up:\n" +
        "  servers: 1234-1234-1234-1234\n" +
        "  volumes: 1111-1111-1111-1111, 0000-0000-0000-0000"
      )
    end

    context 'when there are no tracked resources' do
      it 'says that all have been cleaned up' do
        expect(subject.summary).to eq('All resources have been cleaned up')
      end
    end
  end

  describe '#untrack' do
    let(:compute) {
      double('fog-compute', servers:[], volumes: [], images:[], snapshots:[])
    }

    let(:resources_in_openstack) do
      [
        double('resource1', id:'1234-1234-1234-1234', destroy:true),
        double('resource2', id:'1111-1111-1234-1234', destroy:true)
      ]
    end

    ResourceTracker::RESOURCE_TYPES.each do |type|
      it "cleans up #{type} on a given openstack object" do
        allow(compute).to receive(type).and_return(resources_in_openstack)

        subject.track(type) { '1234-1234-1234-1234' }
        subject.untrack(compute, cleanup: true)

        expect(resources_in_openstack[0]).to have_received(:destroy)
        expect(subject.count).to eq(0)
      end
    end

    context 'if openstack does not have the resource' do
      it 'untracks them' do
        allow(compute).to receive(:servers).and_return(resources_in_openstack)

        subject.track(:servers) { 'non-existing-cid' }
        subject.untrack(compute, cleanup: true)

        expect(subject.count).to eq(0)
      end
    end

    context 'if some resource could not be deleted' do
      let(:resources_in_openstack) do
        [
          double('resource1', id:'1234', destroy:false),
          double('resource2', id:'5678', destroy:true)
        ]
      end

      it 'returns false' do
        allow(compute).to receive(:volumes).and_return(resources_in_openstack)

        subject.track(:volumes) { '1234' }
        subject.track(:volumes) { '5678' }

        expect(subject.untrack(compute, cleanup: true)).to eq(false)

        expect(subject.count).to eq(1)
      end
    end
  end

  context 'when cleanup is skipped' do
    let(:compute) {
      double('fog-compute', servers:[], volumes: [], images:[], snapshots:[])
    }

    let(:resources_in_openstack) do
      [
        double('resource1', id:'1234', destroy:true)
      ]
    end

    it 'does not report resources which do not exist anymore' do
      subject.track(:volumes) { '1234' }

      subject.untrack(compute, cleanup: false)

      expect(subject.count).to eq(0)
    end

    it 'does report resources which do exist' do
      allow(compute).to receive(:volumes).and_return(resources_in_openstack)

      subject.track(:volumes) { '1234' }

      subject.untrack(compute, cleanup: false)

      expect(subject.count).to eq(1)
    end
  end
end