require_relative '../spec_helper'

module Validator

  describe Resources do
    let(:compute) { double('compute', servers: servers, volumes: volumes, images: images) }
    let(:network) { double('network', networks: networks) }


    let(:server_entries){ [] }
    let(:servers) {
      OpenStackResourceCollection.new(server_entries)
    }
    let(:volume_entries){ [] }
    let(:volumes) {
      OpenStackResourceCollection.new(volume_entries)
    }
    let(:image_entries) { [] }
    let(:images) {
      OpenStackResourceCollection.new(image_entries)
    }
    let(:network_entries){ [] }
    let(:networks) {
      OpenStackResourceCollection.new(network_entries)
    }


    before (:each) do
      allow(Api::FogOpenStack).to receive(:compute).and_return(compute)
      allow(Api::FogOpenStack).to receive(:network).and_return(network)
    end

    describe '.create' do

      it 'should create a Resources instance' do
        expect(subject.new_tracker).to be_a(Api::ResourceTracker)
      end
    end

    describe '.cleanup' do
      let(:resources) {
        OpenStackResourceCollection.new([
            {id: '1234-1234-1234-1234', destroyable: true},
            {id: '1111-1111-1234-1234', destroyable: true}
        ])
      }

      context 'when all resources can be cleaned up' do

        Api::ResourceTracker.resource_types.each do |type|
          it "cleans produced resources for #{type}" do
            allow(compute).to receive(type).and_return(resources)
            allow(network).to receive(type).and_return(resources)

            subject.new_tracker.produce(type, provide_as: :resource_id1) {
              '1234-1234-1234-1234'
            }
            subject.new_tracker.produce(type, provide_as: :resource_id2) {
              '1111-1111-1234-1234'
            }

            subject.cleanup

            expect(subject.count).to eq(0)
          end
        end
      end

      context 'when some resource could not be deleted' do
        let(:volume_entries) {
          [
              {id: '1234', destroyable: false},
              {id: '5678', destroyable: true}
          ]
        }

        it 'returns false' do
          subject.new_tracker.produce(:volumes) { '1234' }
          subject.new_tracker.produce(:volumes) { '5678' }
          expect(subject.count).to eq(2)

          expect(subject.cleanup).to eq(false)

          expect(subject.count).to eq(1)
        end
      end

      context 'when some resource does not exist in openstack' do
        let(:image_entries) { [{id: '1234', destroyable: true}] }
        it 'cleans up those resources anyway' do
          subject.new_tracker.produce(:images) { '1234' }

          images.clear

          expect(subject.cleanup).to eq(true)
        end
      end

    end

    describe '.summary' do
      context 'when multiple tests produce resources' do
        let(:server_entries) { [{id: '1234-1234-1234-1234', name: 'server-1'}] }
        let(:volume_entries) { [
            {id: '1111-1111-1111-1111', name: 'volume-1'},
            {id: '0000-0000-0000-0000', name: 'volume-2'}
        ] }
        before(:all) {
          @subject = Resources.new
        }
        it 'a server' do
          @subject.new_tracker.produce(:servers) { '1234-1234-1234-1234' }
        end

        it 'a volume' do
          @subject.new_tracker.produce(:volumes) { '1111-1111-1111-1111' }
        end

        it 'another volume' do
          @subject.new_tracker.produce(:volumes) { '0000-0000-0000-0000' }
        end

        it 'returns all tracked resources as printable string' do
          expect(@subject.summary).to eq(<<EOF
The following resources might not have been cleaned up:
  servers:
    server-1 / 1234-1234-1234-1234 (a server)
  volumes:
    volume-1 / 1111-1111-1111-1111 (a volume)
    volume-2 / 0000-0000-0000-0000 (another volume)
EOF
          )
        end
      end

      context 'when there are no tracked resources' do
        it 'says that all have been cleaned up' do
          expect(subject.summary).to eq('All resources have been cleaned up')
        end
      end

      context 'when openstack does not have the resource' do
        let(:server_entries) { [{id: '1234'}] }

        it 'excludes them from summary' do
          subject.new_tracker.produce(:servers) { '1234' }

          servers.clear

          expect(subject.summary).to eq('All resources have been cleaned up')
        end
      end
    end
  end

  class OpenStackResourceCollection < Array
    def initialize(entries)
      entries.each { |entry|
        self << OpenStackResource.new(self, entry)
      }
    end

    def get(id)
      find { |entry| entry.id == id }
    end

  end

  class OpenStackResource
    attr_reader :id

    def initialize(owner, id:, destroyable: true, name: 'my-resource')
      @owner = owner
      @destroyable = destroyable
      @id = id
      @name = name
    end

    def name
      @name
    end

    def destroy
      @owner.delete(self) if @destroyable
      @destroyable
    end

  end
end