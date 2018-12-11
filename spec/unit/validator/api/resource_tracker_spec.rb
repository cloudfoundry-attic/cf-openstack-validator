require_relative '../../spec_helper'
require 'fog/openstack/volume/v1/models/volume'
require 'fog/openstack/volume/v2/models/volume'
require 'fog/openstack/compute/models/server_group'

module Validator::Api
  describe ResourceTracker do

    let(:compute) { double('compute', servers: resources, key_pairs: resources, flavors: resources, server_groups: resources, delete_server_group: double('delete_server_groups_request')) }
    let(:network) { double('network', networks: resources, routers: resources, subnets: resources, floating_ips: resources, security_groups: resources, security_group_rules: resources, ports: resources) }
    let(:image) { double('image', images: resources) }
    let(:volume) { double('volume', volumes: resources, snapshots: resources) }
    let(:storage) { double('storage', directories: resources, files: resources) }
    let(:resources) { double('resources', get: resource) }
    let(:resource) { double('resource', name: 'my-resource', wait_for: nil) }

    before (:each) do
      allow(FogOpenStack).to receive(:compute).and_return(compute)
      allow(FogOpenStack).to receive(:network).and_return(network)
      allow(FogOpenStack).to receive(:image).and_return(image)
      allow(FogOpenStack).to receive(:volume).and_return(volume)
      allow(FogOpenStack).to receive(:storage).and_return(storage)
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

      context "when ':directories' resource" do
        let(:resource) { double('directory_resource', key: 'my-resource', files: double('files', get: double('file', key: 'my-file')),  wait_for: nil) }

        it 'stores the resource id' do
          subject.produce(:directories, provide_as: :root) { 'directory_id' }

          expect(subject.consumes(:root)).to eq('directory_id')
        end
      end

      context "when ':files' resource" do
        let(:storage) { double('storage', directories: resources, files: file_resources) }
        let(:file_resources) { double('file_resources', get: file_resource) }
        let(:file_resource) { double('file_resource', key: 'my-resource', wait_for: nil) }
        let(:resource) { double('directory_resource', key: 'my-resource', files: double('files', get: double('file', key: 'my-file')),  wait_for: nil) }

        it 'stores the resource id' do
          subject.produce(:files, provide_as: :blob) { ['directory_id', 'file_id'] }

          expect(subject.consumes(:blob)).to eq(['directory_id', 'file_id'])
        end
      end

      context "when ':images' resource" do
        context 'when light stemcell' do
          it 'does not get the resource from OpenStack' do

            subject.produce(:images) { 'id light' }

            expect(resources).to_not have_received(:get)
          end
        end

        it 'stores the resource id' do
          subject.produce(:images, provide_as: :light_stemcell) { 'id light' }

          expect(subject.consumes(:light_stemcell)).to eq('id light')
        end

      end

      context "when ':volumes' resource" do
        before(:each) do
          allow(resource).to receive(:ready?)
          allow(resource).to receive(:wait_for) { |&block| resource.instance_eval(&block) }
        end

        context 'when cinder v1' do
          let(:resource) { instance_double(Fog::OpenStack::Volume::V1::Volume, display_name: 'my-volume') }

          it "stores the resource 'display_name'" do
            subject.produce(:volumes, provide_as: :my_volume) { 'volume-id' }

            volume = subject.resources.find {|resource| resource.fetch(:id) == 'volume-id'}
            expect(volume).to_not be_nil
            expect(volume[:name]).to eq('my-volume')
          end
        end

        context 'when cinder v2' do
          let(:resource) { instance_double(Fog::OpenStack::Volume::V2::Volume, name: 'my-volume') }

          it "stores the resource 'name'" do
            subject.produce(:volumes, provide_as: :my_volume) { 'volume-id' }

            volume = subject.resources.find {|resource| resource.fetch(:id) == 'volume-id'}
            expect(volume).to_not be_nil
            expect(volume[:name]).to eq('my-volume')
          end
        end
      end

      context "when ':server_group' resource" do
        let(:resource) { double('server_group_resource', name: nil, wait_for: nil) }

        it 'stores the resource id' do
          subject.produce(:server_groups, provide_as: :my_group) { 'server_group_id' }

          expect(subject.consumes(:my_group)).to eq('server_group_id')
        end
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
      let(:cpi) { instance_double(Validator::ExternalCpi, delete_vm: nil, delete_stemcell: nil) }
      let(:log_path) { Dir.mktmpdir }

      before do
        allow(Logger).to receive(:new).and_return(nil)
        allow(resource).to receive(:destroy).and_return(true)

        allow(Validator::ExternalCpi).to receive(:new).and_return(cpi)
        allow(RSpec::configuration).to receive(:options).and_return(double('options', cpi_bin_path: nil, log_path: nil))
      end

      after do
        FileUtils.rm_rf( log_path ) if File.exists?( log_path )
      end

      it 'destroys all resources' do
        subject.produce(:servers) { 'server_id' }
        subject.produce(:networks) { 'network_id' }
        subject.produce(:images) { 'image_id' }

        subject.cleanup

        expect(resource).to have_received(:destroy).exactly(1).times
        expect(cpi).to have_received(:delete_vm).with('server_id')
        expect(cpi).to have_received(:delete_stemcell).with('image_id')
      end

      it 'reports true' do
        subject.produce(:images) { 'image_id' }

        success = subject.cleanup

        expect(success).to eq(true)
      end

      context 'when object store' do
        let(:storage) { double('storage', directories: resources, files: file_resources) }
        let(:file_resources) { double('file_resources', get: file_resource) }
        let(:file_resource) { double('file_resource', key: 'my-file', wait_for: nil) }
        let(:resource) { double('directory_resource', key: 'my-resource', files: file_resources, wait_for: nil) }
        let(:validator_config) do
          { 'openstack' => { 'wait_for_swift' => 0 } }
        end

        before do
          allow(file_resource).to receive(:destroy).and_return(true)
          allow(file_resources).to receive(:each).and_yield(file_resource).and_yield(file_resource)
          allow(RSpec::configuration).to receive(:options).and_return(double('options', cpi_bin_path: nil, log_path: nil))
          allow(RSpec::configuration).to receive(:validator_config).and_return(double('config', validator_config))
        end

        context 'when a directory contains files' do
          it 'deletes all files and the directory' do
            subject.produce(:directories) { 'directory_id' }
            subject.produce(:files) { ['directory_id', 'file_1_id'] }
            subject.produce(:files) { ['directory_id', 'file_2_id'] }

            subject.cleanup

            expect(resource).to have_received(:destroy).exactly(1).times
            expect(file_resource).to have_received(:destroy).at_least(2).times
          end
        end

        context 'when file object' do
          it 'deletes the file' do
            subject.produce(:files) { ['directory_id', 'file_id'] }

            subject.cleanup

            expect(resource).to_not have_received(:destroy)
            expect(file_resource).to have_received(:destroy).exactly(1).times
          end

          context 'when file object throws NotFound in destroy' do
            it 'ignores the exception' do
              allow(file_resource).to receive(:destroy).and_raise(Fog::OpenStack::Storage::NotFound)
              subject.produce(:files) { ['directory_id', 'file_id'] }

              result = subject.cleanup

              expect(result).to eq(true)
              expect(resource).to_not have_received(:destroy)
              expect(file_resource).to have_received(:destroy).exactly(1).times
            end
          end
        end
      end

      context 'when server group' do
        let(:resource) { instance_double(Fog::OpenStack::Compute::ServerGroup, wait_for: nil, name: nil) }
        it 'deletes the server group' do
          subject.produce(:server_groups) { 'id' }

          subject.cleanup

          expect(resource).to_not have_received(:destroy)
          expect(compute).to have_received(:delete_server_group).exactly(1).times
        end
      end

      context 'when a resource cannot be destroyed' do
        before do
          allow(resource).to receive(:destroy).and_return(false)
        end

        it 'return false' do
          subject.produce(:volumes) { 'volume_id' }

          success = subject.cleanup

          expect(success).to eq(false)
        end
      end

      [
          Validator::ExternalCpi::CpiError,
          Validator::ExternalCpi::InvalidResponse,
          Validator::ExternalCpi::NonExecutable
      ].each do |error|
        context "when an image cannot be destroyed with #{error}" do
          before do
            allow(cpi).to receive(:delete_stemcell).and_raise(error)
          end

          it 'return false' do
            subject.produce(:images) { 'image_id' }

            success = subject.cleanup

            expect(success).to eq(false)
          end
        end

        context "when a server cannot be destroyed #{error}" do
          before do
            cpi = instance_double(Validator::ExternalCpi)
            allow(cpi).to receive(:delete_vm).and_raise(error)
            allow(Validator::ExternalCpi).to receive(:new).and_return(cpi)
          end

          it 'return false' do
            subject.produce(:servers) { 'server_id' }

            success = subject.cleanup

            expect(success).to eq(false)
          end
        end
      end
    end

    describe '#count' do
      it 'returns number of tracked resources' do
        expect(subject.count).to eq(0)
      end
    end

    describe '#resources' do

      def mock_all_service_types(general_resource_mock, storage_resource_mock)
        # We don't have access to some Base instances here therefore we need to mock the class.
        # Mocking the same method of subclasses and their parent class at the same time is only working if the parent class is mocked last.
        # So it is order dependent therefor we did not do it.
        allow_any_instance_of(Validator::Api::ResourceTracker::Base).to receive(:get_ready).and_return(general_resource_mock)
        ResourceTracker::RESOURCE_SERVICES.each do |_, types|
          types.each do |type|
            if type == :files || type == :directories
              allow(ResourceTracker::RESOURCE_HANDLER.fetch(type)).to receive(:get_ready).and_return(storage_resource_mock)
            elsif ResourceTracker::RESOURCE_HANDLER.key?(type)
              allow(ResourceTracker::RESOURCE_HANDLER.fetch(type)).to receive(:get_ready).and_return(general_resource_mock)
            end
          end
        end
      end

      before(:each) do
        mock_all_service_types(double('resource', name: 'some-name', wait_for: nil), double('resource', key: 'some-name', wait_for: nil))
        ResourceTracker::RESOURCE_SERVICES.each do |_, types|
          types.each do |type|
            subject.produce(type) { "#{type}-id" }
          end
        end

        expect(subject.resources.length).to eq(16)
      end

      it 'returns all resources existing in openstack' do
        expect(subject.resources.length).to eq((ResourceTracker::RESOURCE_SERVICES.to_a.flatten - ResourceTracker::RESOURCE_SERVICES.keys).length)
      end

      it 'when resources do not exist in openstack anymore it does not include them' do
        mock_all_service_types(nil, nil)

        expect(subject.resources.length).to eq(0)
      end
    end

  end
end
