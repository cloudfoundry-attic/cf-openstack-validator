require_relative '../../spec_helper'

module Validator::Api
  describe FogOpenStack do

    before(:each) do
      configuration = instance_double(Validator::Configuration)
      allow(configuration).to receive(:openstack).and_return({})
      allow(CfValidator).to receive(:configuration).and_return(configuration)
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
    end
  end
end
