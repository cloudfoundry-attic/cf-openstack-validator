require_relative '../../spec_helper'

module Validator::Api
  describe FogOpenStack do

    let(:openstack_params) { {} }

    before(:each) do
      configuration = instance_double(Validator::Api::Configuration)
      allow(configuration).to receive(:openstack).and_return(openstack_params)
      allow(Validator::Api).to receive(:configuration).and_return(configuration)
    end

    describe '.image' do

      context 'when V2 is available' do
        before(:each) do
          allow(Fog::Image::OpenStack::V2).to receive(:new).and_return(instance_double(Fog::Image::OpenStack::V2))
        end

        it 'uses V2 by default' do
          FogOpenStack.image

          expect(Fog::Image::OpenStack::V2).to have_received(:new)
        end
      end

      context 'when only V1 is supported' do
        before(:each) do
          allow(Fog::Image::OpenStack::V2).to receive(:new).and_raise(Fog::OpenStack::Errors::ServiceUnavailable)
          allow(Fog::Image::OpenStack::V1).to receive(:new).and_return(instance_double(Fog::Image::OpenStack::V1))
        end

        it 'falls back to V1' do
          FogOpenStack.image

          expect(Fog::Image::OpenStack::V1).to have_received(:new)
        end
      end

      context 'when V2 raises other than ServiceUnavailable' do
        before(:each) do
          allow(Fog::Image::OpenStack::V1).to receive(:new)
          allow(Fog::Image::OpenStack::V2).to receive(:new).and_raise('some_error')
        end

        it 'raises' do
          expect {
            FogOpenStack.image
          }.to raise_error('some_error')
        end
      end

      context 'when a socket error occurs' do
        let(:openstack_params){ { 'auth_url' => 'http://some.url' } }

        before(:each) do
          allow(Fog::Image::OpenStack::V2).to receive(:new).and_raise(Excon::Errors::SocketError)
        end

        it 'includes the url on the error message' do
          expect {
            FogOpenStack.image
          }.to raise_error(Validator::Api::ValidatorError, /Could not connect to 'http:\/\/some.url' \nException message:.*\nBacktrace:/)
        end
      end
    end

    describe '.volume' do

      context 'when V2 is available' do
        before(:each) do
          allow(Fog::Volume::OpenStack::V2).to receive(:new).and_return(instance_double(Fog::Volume::OpenStack::V2))
        end

        it 'uses V2 by default' do
          FogOpenStack.volume

          expect(Fog::Volume::OpenStack::V2).to have_received(:new)
        end
      end

      context 'when only V1 is supported' do
        before(:each) do
          allow(Fog::Volume::OpenStack::V2).to receive(:new).and_raise(Fog::OpenStack::Errors::ServiceUnavailable)
          allow(Fog::Volume::OpenStack::V1).to receive(:new).and_return(instance_double(Fog::Volume::OpenStack::V1))
        end

        it 'falls back to V1' do
          FogOpenStack.volume

          expect(Fog::Volume::OpenStack::V1).to have_received(:new)
        end
      end

      context 'when V2 raises other than ServiceUnavailable' do
        before(:each) do
          allow(Fog::Volume::OpenStack::V1).to receive(:new)
          allow(Fog::Volume::OpenStack::V2).to receive(:new).and_raise('some_error')
        end

        it 'raises' do
          expect {
            FogOpenStack.volume
          }.to raise_error('some_error')
        end
      end

      context 'when a socket error occurs' do
        let(:openstack_params){ { 'auth_url' => 'http://some.url' } }

        before(:each) do
          allow(Fog::Volume::OpenStack::V2).to receive(:new).and_raise(Excon::Errors::SocketError)
        end

        it 'wraps the error' do
          expect {
            FogOpenStack.volume
          }.to raise_error(Validator::Api::ValidatorError, /Could not connect to 'http:\/\/some.url' \nException message:.*\nBacktrace:/)
        end
      end
    end

    describe '.compute' do
      context 'when a socket error occurs' do
        let(:openstack_params){ { 'auth_url' => 'http://some.url' } }

        before(:each) do
          allow(Fog::Compute::OpenStack).to receive(:new).and_raise(Excon::Errors::SocketError)
        end

        it 'wraps the error' do
          expect {
            FogOpenStack.compute
          }.to raise_error(Validator::Api::ValidatorError, /Could not connect to 'http:\/\/some.url' \nException message:.*\nBacktrace:/)
        end
      end

      context 'when correct openstack params are passed' do
        let(:openstack_params){ { 'auth_url' => 'http://some.url' } }
        it 'uses and converts those into FOG params' do
          expect(Fog::Compute::OpenStack).to receive(:new).with(hash_including(:openstack_auth_url => 'http://some.url'))
          FogOpenStack.compute
        end
      end
    end

    describe '.network' do
      context 'when a socket error occurs' do
        let(:openstack_params){ { 'auth_url' => 'http://some.url' } }

        before(:each) do
          allow(Fog::Network::OpenStack).to receive(:new).and_raise(Excon::Errors::SocketError)
        end

        it 'wraps the error' do
          expect {
            FogOpenStack.network
          }.to raise_error(Validator::Api::ValidatorError, /Could not connect to 'http:\/\/some.url' \nException message:.*\nBacktrace:/)
        end
      end
    end

    describe '.storage' do
      context 'when a socket error occurs' do
        let(:openstack_params){ { 'auth_url' => 'http://some.url' } }

        before(:each) do
          allow(Fog::Storage::OpenStack).to receive(:new).and_raise(Excon::Errors::SocketError)
        end

        it 'wraps the error' do
          expect {
            FogOpenStack.storage
          }.to raise_error(Validator::Api::ValidatorError, /Could not connect to 'http:\/\/some.url' \nException message:.*\nBacktrace:/)
        end
      end

      context 'when correct openstack params are passed' do
        let(:openstack_params){ { 'auth_url' => 'http://some.url' } }
        it 'uses and converts those into FOG params' do
          expect(Fog::Storage::OpenStack).to receive(:new).with(hash_including(:openstack_auth_url => 'http://some.url'))
          FogOpenStack.storage
        end
      end
    end

    describe '.with_openstack' do
      it 'calls the given block' do
        expect(FogOpenStack.with_openstack('some message') { 'Yeah!' }).to eq('Yeah!')
      end

      context 'when block raises an error' do
        let(:logger) { instance_double(Logger) }

        before do
          allow(Logger).to receive(:new).and_return(logger)
          allow(logger).to receive(:error)
          allow(RSpec::configuration).to receive(:options).and_return(double('options', cpi_bin_path: nil, log_path: 'some_file_path'))
        end

        it 're-raises error with the given error message and hint to log file' do
          expect{
            FogOpenStack.with_openstack('some user-defined message') { raise 'original error message' }
          }.to raise_error("some user-defined message: More details can be found in 'some_file_path'")
        end

        it 'logs the original error message' do
          expect{
            FogOpenStack.with_openstack('some user-defined message') { raise 'original error message' }
          }.to raise_error(/some user-defined message/)

          expect(logger).to have_received(:error).with('original error message')
        end

        context "when error type is 'Excon::Errors::Forbidden'" do
          let(:configuration) { instance_double(Validator::Api::Configuration, openstack: { 'username' => 'some-user' }) }

          before(:each) do
            allow(Validator::Api).to receive(:configuration).and_return(configuration)
          end
          it 're-raises error with helping message' do
            expect{
              FogOpenStack.with_openstack('some user-defined message') { raise Excon::Errors::Forbidden.new 'original error message' }
            }.to raise_error("some user-defined message: The user 'some-user' does not have required permissions.")
          end
        end
      end
    end
  end
end
